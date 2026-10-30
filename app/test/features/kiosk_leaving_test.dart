import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../helpers.dart' show FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('kiosk "I\'m leaving": lists, switches off, arms, says bye', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(1280, 800),
      speech: speech,
    );
    await settle(tester, 10);
    final server = HomeFixture.running;
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    expect(server.stateOf('fx:light.living_room_main'), 'on');

    await tapKey(tester, 'kioskLeaving');
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskLeavingDialog')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('leaving-fx:light.living_room_main')),
      findsOneWidget,
    );
    await tapKey(tester, 'kioskLeavingGo');
    await settle(tester, 10);
    expect(server.stateOf('fx:light.living_room_main'), 'off');
    expect(server.stateOf('fx:light.living_room_ambient'), 'off');
    expect(server.stateOf('fx:alarm_control_panel.home_alarm'), 'armed_away');
    expect(speech.said, [en.kioskLeavingBye]);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskLeavingDialog')), findsNothing);
    await unmount(tester);
  });
}
