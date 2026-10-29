import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/household/family_messages.dart';
import 'package:open_smart_home_lite/features/notifications/application/notifications_provider.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('message ids carry the recipient', () {
    final m = FamilyMessage.from(
      const HaNotification(
        id: 'osh_msg_ana_maria_1760000000000',
        message: 'Supa je u **frižideru**',
      ),
    )!;
    expect(m.to, 'ana_maria');
    expect(m.text, 'Supa je u frižideru');
    expect(m.isFor('person.ana_maria'), isTrue);
    expect(m.isFor('person.marko'), isFalse);
    expect(
      FamilyMessage.from(const HaNotification(id: 'washer_done', message: '')),
      isNull,
    );
  });

  testWidgets('phone: leave a message for Ana in HA, then mark it read', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    await tester.ensureVisible(find.byKey(const Key('openMessages')));
    await tapKey(tester, 'openMessages');
    await settle(tester, 3);
    expect(find.text(en.familyMessagesNone), findsOneWidget);
    await tapKey(tester, 'familyMessageNew');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('familyTo-person.ana')));
    await tester.enterText(
      find.byKey(const Key('familyMessageText')),
      'Supa je u frižideru',
    );
    await tapKey(tester, 'familyMessageSend');
    await settle(tester, 6);
    final id = server.notifications.keys.singleWhere(
      (k) => k.startsWith('osh_msg_ana_'),
    );
    expect(server.notifications[id]!['title'], en.familyMessageFor('Ana'));
    expect(find.text('Supa je u frižideru'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('familyMessageRead-$id')));
    await settle(tester, 6);
    expect(server.notifications.containsKey(id), isFalse);
    expect(find.text(en.familyMessagesNone), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kiosk: Ana comes home, is greeted and hears her message', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      speech: speech,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    server.callService('persistent_notification', 'create', {
      'notification_id': 'osh_msg_ana_1',
      'title': 'Poruka',
      'message': 'Supa je u frižideru',
    });
    await settle(tester, 4);
    expect(
      find.descendant(
        of: find.byKey(const Key('kioskMessages')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    server.setStateForTest('person.ana', 'home');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskWelcome')), findsOneWidget);
    expect(find.text(en.welcomeHome('Ana')), findsOneWidget);
    expect(find.text('Supa je u frižideru'), findsOneWidget);
    expect(
      speech.said.single,
      '${en.welcomeHome('Ana')} ${en.familyMessages}: Supa je u frižideru',
    );
    await tapKey(tester, 'kioskWelcomeClose');
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskWelcome')), findsNothing);
    await unmount(tester);
  });
}
