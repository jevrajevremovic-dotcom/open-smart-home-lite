import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('arm away, then disarm with the keypad (wrong, then right)', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('fx:alarm_control_panel.home_alarm'));
    await settle(tester, 4);
    expect(find.text(en.alarmDisarmed), findsWidgets);
    await tapKey(tester, 'alarmArm-away');
    await settle(tester, 6);
    expect(find.text('${en.alarmArmed} · ${en.alarmArm_away}'), findsWidgets);

    Future<void> enterCode(String code) async {
      await tapKey(tester, 'alarmDisarm');
      await settle(tester, 2);
      for (final digit in code.split('')) {
        await tester.tap(find.byKey(ValueKey('alarmKey-$digit')));
        await tester.pump();
      }
      await tapKey(tester, 'alarmCodeOk');
      await settle(tester, 2);
      await tapKey(tester, 'confirmCriticalAction');
      await settle(tester, 6);
    }

    await enterCode('9999');
    expect(find.text(en.alarmDisarmed), findsNothing, reason: 'wrong code');
    await enterCode('1234');
    expect(find.text(en.alarmDisarmed), findsWidgets);
    await unmount(tester);
  });
}
