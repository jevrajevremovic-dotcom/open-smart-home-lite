import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart' show FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('kiosk: smoke covers the screen, is spoken, "got it" hides it', (
    tester,
  ) async {
    // Server time only moves forward (the app ignores older updates): it
    // starts half an hour back, so the door can open "15 minutes ago".
    var now = DateTime.now().subtract(const Duration(minutes: 30));
    void tick() => now = now.add(const Duration(seconds: 10));
    final server = MockHomeAssistantServer(
      clock: () => now,
      states: [
        ...buildMockStates(now),
        {
          'entity_id': 'binary_sensor.kitchen_smoke',
          'state': 'off',
          'attributes': {
            'friendly_name': 'Dim kuhinja',
            'device_class': 'smoke',
          },
          'last_changed': now.toUtc().toIso8601String(),
          'last_updated': now.toUtc().toIso8601String(),
        },
      ],
    );
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      server: server,
      speech: speech,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    expect(find.byKey(const Key('kioskAlertCritical')), findsNothing);

    tick();
    server.setStateForTest('binary_sensor.kitchen_smoke', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskAlertCritical')), findsOneWidget);
    expect(find.text('Dim kuhinja'), findsWidgets);
    expect(speech.said.single, startsWith('Warning! Dim kuhinja'));

    await tapKey(tester, 'kioskAlertSeen');
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskAlertCritical')), findsNothing);

    // Cleared, then again: back on screen and spoken again.
    tick();
    server.setStateForTest('binary_sensor.kitchen_smoke', 'off');
    await settle(tester, 3);
    tick();
    server.setStateForTest('binary_sensor.kitchen_smoke', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskAlertCritical')), findsOneWidget);
    expect(speech.said, hasLength(2));
    await tapKey(tester, 'kioskAlertSeen');
    await settle(tester, 2);

    // A door opened 15 minutes ago (default limit 10).
    now = DateTime.now().subtract(const Duration(minutes: 15));
    server.setStateForTest('binary_sensor.front_door', 'on');
    await tester.pump(const Duration(seconds: 31));
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskAlertOpen')), findsOneWidget);
    expect(find.textContaining(en.kioskAlertOpenFor(15)), findsOneWidget);
    expect(speech.said, hasLength(2), reason: 'open doors are not spoken');
    await tapKey(tester, 'kioskAlertSeen');
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskAlertOpen')), findsNothing);

    // A window opened just now: nothing yet.
    now = DateTime.now();
    server.setStateForTest('binary_sensor.bedroom_window', 'on');
    await tester.pump(const Duration(seconds: 31));
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskAlertOpen')), findsNothing);
    await unmount(tester);
  });
}
