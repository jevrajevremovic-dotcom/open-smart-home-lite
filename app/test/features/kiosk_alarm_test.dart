import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('kiosk: shield in the header arms and disarms with the code', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1280, 800));
    await settle(tester, 10);
    final server = HomeFixture.running;
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);

    expect(find.byTooltip(en.alarmDisarmed), findsOneWidget);
    await tapKey(tester, 'kioskAlarm');
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskAlarmDialog')), findsOneWidget);
    await tapKey(tester, 'alarmArm-away');
    await settle(tester, 6);
    expect(server.stateOf('fx:alarm_control_panel.home_alarm'), 'armed_away');

    await tapKey(tester, 'alarmDisarm');
    await settle(tester, 2);
    for (final digit in '1234'.split('')) {
      await tester.tap(find.byKey(ValueKey('alarmKey-$digit')));
      await tester.pump();
    }
    await tapKey(tester, 'alarmCodeOk');
    await settle(tester, 2);
    await tapKey(tester, 'confirmCriticalAction');
    await settle(tester, 6);
    expect(server.stateOf('fx:alarm_control_panel.home_alarm'), 'disarmed');
    await unmount(tester);
  });
}
