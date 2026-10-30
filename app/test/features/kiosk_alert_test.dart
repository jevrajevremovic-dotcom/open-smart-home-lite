import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../helpers.dart' show FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('kiosk: smoke covers the screen, is spoken, "got it" hides it', (
    tester,
  ) async {
    // Devices' time starts half an hour back, so the door can open
    // "15 minutes ago".
    var now = DateTime.now().subtract(const Duration(minutes: 30));
    void tick() => now = now.add(const Duration(seconds: 10));
    final server = HomeFixture(clock: () => now);
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      adapter: server,
      size: const Size(1280, 800),
      speech: speech,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    expect(find.byKey(const Key('kioskAlertCritical')), findsNothing);

    tick();
    server.setRaw('fx:binary_sensor.kitchen_smoke', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskAlertCritical')), findsOneWidget);
    expect(find.text('Dim kuhinja'), findsWidgets);
    expect(speech.said.single, startsWith('Warning! Dim kuhinja'));

    await tapKey(tester, 'kioskAlertSeen');
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskAlertCritical')), findsNothing);

    // Cleared, then again: back on screen and spoken again.
    tick();
    server.setRaw('fx:binary_sensor.kitchen_smoke', 'off');
    await settle(tester, 3);
    tick();
    server.setRaw('fx:binary_sensor.kitchen_smoke', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskAlertCritical')), findsOneWidget);
    expect(speech.said, hasLength(2));
    await tapKey(tester, 'kioskAlertSeen');
    await settle(tester, 2);

    // A door opened 15 minutes ago (default limit 10).
    now = DateTime.now().subtract(const Duration(minutes: 15));
    server.setRaw('fx:binary_sensor.front_door', 'on');
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
    server.setRaw('fx:binary_sensor.bedroom_window', 'on');
    await tester.pump(const Duration(seconds: 31));
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskAlertOpen')), findsNothing);
    await unmount(tester);
  });
}
