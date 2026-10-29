import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/extras/vacation.dart';

import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('holiday: heating down and back, remembered on this device', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final thermostats = vacationThermostats(
      container.read(homeSnapshotProvider).devices.values,
    );
    expect(thermostats, isNotEmpty);
    final before = {
      for (final t in thermostats) t.id: t.state.targetTemperature,
    };

    await tapKey(tester, 'openExtras');
    await settle(tester, 2);
    await tapKey(tester, 'extraVacation');
    await settle(tester, 2);
    expect(find.text(en.vacationTitle), findsWidgets);
    await tapKey(tester, 'vacationStart');
    await settle(tester, 8);
    // The alarm wants a code in the demo home: cancel that part.
    if (find.text(en.cancel).evaluate().isNotEmpty) {
      await tester.tap(find.text(en.cancel).last);
      await settle(tester, 3);
    }

    expect(container.read(vacationProvider).active, isTrue);
    for (final t in thermostats) {
      expect(container.read(deviceProvider(t.id))!.state.targetTemperature, 16);
    }
    expect(find.text(en.vacationActive), findsOneWidget);

    await tapKey(tester, 'vacationEnd');
    await settle(tester, 6);
    expect(container.read(vacationProvider).active, isFalse);
    for (final t in thermostats) {
      expect(
        container.read(deviceProvider(t.id))!.state.targetTemperature,
        before[t.id],
      );
    }
    await unmount(tester);
  });
}
