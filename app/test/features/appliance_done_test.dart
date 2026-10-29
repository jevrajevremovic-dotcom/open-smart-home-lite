import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/appliance_done/appliance_done.dart';
import 'package:open_smart_home_lite/features/household/family_messages.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeAlertNotifier;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('automation: running, then quiet for a while, then the messages', () {
    const done = ApplianceDone(
      powerId: 'sensor.washer_plug_power',
      name: 'Veš mašina',
      thresholdWatts: 10,
      doneMinutes: 5,
      notify: ['notify.mobile_app_marko'],
    );
    final c = done.automation(AppLocalizationsEn());
    expect(done.id, 'osh_done_sensor_washer_plug_power');
    expect(c['triggers'], [
      {
        'trigger': 'numeric_state',
        'entity_id': 'sensor.washer_plug_power',
        'above': 10,
        'for': {'minutes': applianceStartMinutes},
      },
    ]);
    final actions = c['actions']! as List;
    expect(actions[0], {
      'wait_for_trigger': [
        {
          'trigger': 'numeric_state',
          'entity_id': 'sensor.washer_plug_power',
          'below': 10,
          'for': {'minutes': 5},
        },
      ],
      'timeout': {'hours': 12},
      'continue_on_timeout': false,
    });
    expect((actions[1] as Map)['action'], 'notify.mobile_app_marko');
    final household = actions[2] as Map;
    expect(household['action'], 'persistent_notification.create');
    final id = (household['data'] as Map)['notification_id'] as String;
    expect(id, startsWith('${FamilyMessage.prefix}${FamilyMessage.everyone}_'));
    // Read back for editing.
    final back = ApplianceDone.fromAutomation(c)!;
    expect(back.name, 'Veš mašina');
    expect(back.thresholdWatts, 10);
    expect(back.doneMinutes, 5);
    expect(back.notify, ['notify.mobile_app_marko']);
    expect(back.household, isTrue);
  });

  testWidgets('on the plug: set up, everyone told, change, remove', (
    tester,
  ) async {
    final alerts = FakeAlertNotifier();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: alerts,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);

    // The plug's own screen offers it (its power sensor is a sibling).
    await goTo(tester, AppRoutes.device('switch.washer_plug'));
    await settle(tester, 6);
    await tester.ensureVisible(find.byKey(const Key('applianceDone')));
    await tapKey(tester, 'applianceDone');
    await settle(tester, 3);
    expect(find.text(en.applianceDoneNow('420')), findsOneWidget);
    // Without messages from Home Assistant: only the household.
    expect(find.text(en.applianceDoneNeedsPush), findsOneWidget);
    final name = tester.widget<TextField>(
      find.byKey(const Key('applianceDoneName')),
    );
    expect(name.controller!.text, 'Veš mašina');
    await tapKey(tester, 'applianceDoneSave');
    await settle(tester, 6);
    expect(find.text(en.applianceDoneSaved('Veš mašina')), findsOneWidget);
    final config = server.automations['osh_done_sensor_washer_plug_power']!;
    expect(find.byKey(const Key('applianceDoneSet')), findsOneWidget);

    // What it does when the cycle ends, run on the server.
    final create = (config['actions']! as List).last as Map;
    final messages = container.listen(familyMessagesProvider, (_, _) {});
    await settle(tester, 2);
    server.callService('persistent_notification', 'create', {
      ...Map<String, Object?>.from(create['data']! as Map),
      'notification_id': '${FamilyMessage.prefix}all_1',
    });
    await settle(tester, 4);
    expect(
      messages.read().map((m) => (m.to, m.text)),
      contains((FamilyMessage.everyone, en.applianceDoneMessage('Veš mašina'))),
    );
    messages.close();

    // Change: read back, new threshold.
    await tester.ensureVisible(find.byKey(const Key('applianceDoneEdit')));
    await tapKey(tester, 'applianceDoneEdit');
    await settle(tester, 4);
    await tapKey(tester, 'applianceDoneThreshold');
    await settle(tester, 2);
    await tester.tap(find.text('20 W').last);
    await settle(tester, 2);
    await tapKey(tester, 'applianceDoneSave');
    await settle(tester, 6);
    expect(
      ((server.automations['osh_done_sensor_washer_plug_power']!['triggers']!
                  as List)
              .single
          as Map)['above'],
      20,
    );

    await tapKey(tester, 'applianceDoneEdit');
    await settle(tester, 4);
    await tapKey(tester, 'applianceDoneRemove');
    await settle(tester, 6);
    expect(server.automations, isEmpty);
    expect(find.byKey(const Key('applianceDone')), findsOneWidget);
    await unmount(tester);
  });
}
