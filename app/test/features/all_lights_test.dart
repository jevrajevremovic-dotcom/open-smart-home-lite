import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('room: all lights off and on; home: all off from summary', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    expect(find.text(en.lightsOnOf(2, 3)), findsOneWidget);

    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    await tapKey(tester, 'allLightsOff');
    await settle(tester, 6);
    await goTo(tester, AppRoutes.home);
    await settle(tester, 4);
    expect(find.text(en.lightsOnOf(0, 3)), findsOneWidget);

    await tapKey(tester, 'summaryLights');
    await settle(tester, 4);
    await tapKey(tester, 'allLightsOn');
    await settle(tester, 6);
    Navigator.of(tester.element(find.byKey(const Key('allLightsOn')))).pop();
    await settle(tester, 4);
    expect(find.text(en.lightsOnOf(3, 3)), findsOneWidget);
    await unmount(tester);
  });
}
