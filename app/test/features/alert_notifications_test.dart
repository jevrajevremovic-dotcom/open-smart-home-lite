import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/presentation/device_detail_screen.dart';

import '../home_fixture.dart';
import '../helpers.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('opt-in alert notifications follow critical alerts', (
    tester,
  ) async {
    final alerts = FakeAlertNotifier();
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1600),
      alerts: alerts,
    );
    await settle(tester, 10);
    final server = HomeFixture.running;

    server.setRaw('fx:lock.front_door', 'jammed');
    await settle(tester, 4);
    expect(alerts.shown, isEmpty, reason: 'off until the user opts in');

    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'alertNotifySwitch');
    await settle(tester, 4);
    expect(alerts.shown.keys, ['fx:lock.front_door']);
    expect(alerts.shown['fx:lock.front_door']!.$1, 'Brava ulazna vrata');

    alerts.tap('fx:lock.front_door');
    await settle(tester, 6);
    expect(find.byType(DeviceDetailScreen), findsOneWidget);

    server.setRaw('fx:lock.front_door', 'locked');
    await settle(tester, 4);
    expect(alerts.shown, isEmpty, reason: 'resolved alerts are cleared');
    await unmount(tester);
  });

  testWidgets('denied permission leaves alerts off', (tester) async {
    final alerts = FakeAlertNotifier(permission: false);
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1600),
      alerts: alerts,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'alertNotifySwitch');
    await settle(tester, 4);
    expect(find.text(en.alertsPermissionDenied), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('alertNotifySwitch')))
          .value,
      isFalse,
    );
    await unmount(tester);
  });
}
