import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/ha_notify/ha_push.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeAlertNotifier, FakeBackgroundConnection;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('notify service name follows Home Assistant slugs', () {
    expect(haSlug('Zidni tablet – Hodnik'), 'zidni_tablet_hodnik');
    expect(haSlug('Đorđev telefon'), 'dordev_telefon');
    expect(
      const MobileAppRegistration(
        webhookId: 'x',
        deviceName: 'Kuhinja Tablet',
      ).notifyService,
      'notify.mobile_app_kuhinja_tablet',
    );
  });

  testWidgets('register, receive and confirm a message, then sign out', (
    tester,
  ) async {
    final notifier = FakeAlertNotifier();
    final credentials = await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: notifier,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('haPushName')), 'Zidni tablet');
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);

    expect(server.mobileApps, hasLength(1));
    final body = server.mobileApps.values.single;
    expect(body['device_name'], 'Zidni tablet');
    expect((body['app_data']! as Map)['push_websocket_channel'], isTrue);
    expect(
      find.text(en.haPushReady('notify.mobile_app_zidni_tablet')),
      findsOneWidget,
    );
    // The webhook id is a secret: stored with the credentials.
    expect(
      credentials.values.keys,
      contains('mobile_app::http://homeassistant.local:8123'),
    );

    final webhook = server.mobileApps.keys.single;
    server.sendPush(webhook, title: 'Veš', message: 'Pranje je završeno.');
    await settle(tester, 4);
    expect(notifier.messages, [('Veš', 'Pranje je završeno.')]);
    expect(server.confirmedPushes, hasLength(1), reason: 'confirmed');

    // A dropped connection resubscribes when it is back.
    await server.dropAllConnections();
    await settle(tester, 40);
    server.sendPush(webhook, message: 'Ponovo tu');
    await settle(tester, 4);
    expect(notifier.messages.last, (null, 'Ponovo tu'));

    await goTo(tester, AppRoutes.settingsSection('server'));
    await tapKey(tester, 'signOutButton');
    await settle(tester, 3);
    await tapKey(tester, 'confirmDialogAction');
    await settle(tester, 5);
    expect(credentials.values, isEmpty, reason: 'webhook id removed too');
    await unmount(tester);
  });

  testWidgets('connection service runs only while wanted and registered', (
    tester,
  ) async {
    final background = FakeBackgroundConnection();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: FakeAlertNotifier(),
      background: background,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);
    expect(background.running, isFalse, reason: 'opt-in');

    await tapKey(tester, 'haPushBackground');
    await settle(tester, 3);
    expect(background.running, isTrue);
    expect(background.text, en.haPushServiceText);

    await tapKey(tester, 'haPushForget');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('haPushForgetConfirm')));
    await settle(tester, 4);
    expect(background.running, isFalse, reason: 'nothing to listen for');
    await unmount(tester);
  });

  testWidgets(
    'a device removed in Home Assistant is forgotten, no retry loop',
    (tester) async {
      final notifier = FakeAlertNotifier();
      await pumpApp(
        tester,
        signedIn: true,
        size: const Size(800, 1600),
        alerts: notifier,
      );
      await settle(tester, 10);
      final server = ProviderScope.containerOf(
        tester.element(find.byType(SmartHomeApp)),
      ).read(mockHomeAssistantServerProvider);
      await goTo(tester, AppRoutes.settingsSection('notifications'));
      await tapKey(tester, 'haPushTile');
      await settle(tester, 3);
      await tester.tap(find.byKey(const Key('haPushRegister')));
      await settle(tester, 8);

      // Removed under Mobile App in Home Assistant, then a reconnect.
      server.mobileApps.clear();
      await server.dropAllConnections();
      await settle(tester, 40);
      expect(find.text(en.haPushRemovedInHa), findsOneWidget);
      expect(find.byKey(const Key('haPushTest')), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets('buttons answer Home Assistant; tag replaces and clears', (
    tester,
  ) async {
    final notifier = FakeAlertNotifier();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: notifier,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);
    final webhook = server.mobileApps.keys.single;

    server.sendPush(
      webhook,
      title: 'Ulazna vrata',
      message: 'Neko zvoni.',
      data: {
        'tag': 'door',
        'entity_id': 'lock.front_door',
        'actions': [
          {'action': 'OPEN_DOOR', 'title': 'Otvori'},
          {'action': 'IGNORE', 'title': 'Ignoriši'},
          {'action': 'REPLY', 'title': 'Odgovori'},
        ],
      },
    );
    await settle(tester, 4);
    final shown = notifier.messageDetails.last;
    expect(shown.key, 'ha-tag-door');
    expect(shown.actions, [('OPEN_DOOR', 'Otvori'), ('IGNORE', 'Ignoriši')]);

    notifier.tapMessage('IGNORE');
    await settle(tester, 4);
    expect(server.firedEvents, [
      {
        'event_type': 'mobile_app_notification_action',
        'event_data': {'action': 'IGNORE', 'tag': 'door'},
      },
    ]);

    // A plain tap opens the device the message is about.
    notifier.tapMessage();
    await settle(tester, 6);
    expect(find.text('Brava ulazna vrata'), findsWidgets);

    notifier.shown['ha-tag-door'] = ('x', 'y');
    server.sendPush(
      webhook,
      message: 'clear_notification',
      data: {'tag': 'door'},
    );
    await settle(tester, 4);
    expect(notifier.shown.containsKey('ha-tag-door'), isFalse);
    await unmount(tester);
  });
}
