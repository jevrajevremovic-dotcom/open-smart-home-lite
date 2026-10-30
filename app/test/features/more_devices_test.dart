import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('vacuum, select and fan from their device screens', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);

    await goTo(tester, AppRoutes.device('fx:vacuum.robot'));
    await settle(tester, 4);
    expect(find.text(en.vacuumDocked), findsWidgets);
    await tapKey(tester, 'vacuumStart');
    await settle(tester, 6);
    expect(find.text(en.vacuumCleaning), findsWidgets);
    await tapKey(tester, 'vacuumReturnHome');
    await settle(tester, 6);
    expect(find.text(en.vacuumReturning), findsWidgets);

    await goTo(tester, AppRoutes.device('fx:input_select.house_mode'));
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('option-Noć')));
    await settle(tester, 6);
    expect(find.text('Noć'), findsWidgets);

    await goTo(tester, AppRoutes.device('fx:fan.bedroom_fan'));
    await settle(tester, 4);
    await tapKey(tester, 'fanOscillate');
    await settle(tester, 6);
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('fanOscillate')),
    );
    expect(sw.value, isTrue);
    await unmount(tester);
  });
}
