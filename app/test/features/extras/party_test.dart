import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/extras/party.dart';

import '../../widgets/app_widget_test.dart'
    show pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('party: colour lights dance, then go back as they were', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final lights = partyLights(
      container.read(homeSnapshotProvider).devices.values,
    );
    expect(lights, isNotEmpty);
    final before = {for (final l in lights) l.id: l.state};

    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraParty');
    await settle(tester, 2);
    await tapKey(tester, 'partyStart');
    await settle(tester, 2);
    expect(find.byKey(const Key('partyScreen')), findsOneWidget);
    await tester.pump(PartyRunner.step * 2);
    await settle(tester, 2);
    for (final l in lights) {
      final s = container.read(deviceProvider(l.id))!.state;
      expect(s.isOn, isTrue);
      expect(s.rgb, isNotNull);
    }

    await tapKey(tester, 'partyStop');
    await settle(tester, 4);
    expect(find.byKey(const Key('partyScreen')), findsNothing);
    for (final l in lights) {
      final s = container.read(deviceProvider(l.id))!.state;
      expect(s.isOn, before[l.id]!.isOn, reason: l.id);
      if (before[l.id]!.isOn == true) {
        expect(s.brightnessPercent, before[l.id]!.brightnessPercent);
      }
    }
    await unmount(tester);
  });

  testWidgets('closed some other way, the lights still go back', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final lights = partyLights(
      container.read(homeSnapshotProvider).devices.values,
    );
    final before = {for (final l in lights) l.id: l.state};
    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraParty');
    await settle(tester, 2);
    await tapKey(tester, 'partyStart');
    await settle(tester, 2);
    await tester.pump(PartyRunner.step * 2);
    // As when the wall panel goes back to its start after a while.
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((r) => r is! PopupRoute && r is! RawDialogRoute);
    await settle(tester, 6);
    await tester.pump(PartyRunner.step * 2);
    await settle(tester, 2);
    for (final l in lights) {
      final now = container.read(deviceProvider(l.id))!.state;
      expect(now.isOn, before[l.id]!.isOn, reason: l.id);
      // Not still dancing at full brightness.
      if (now.isOn == true) {
        expect(now.brightnessPercent, before[l.id]!.brightnessPercent);
        expect(now.rgb, before[l.id]!.rgb);
      }
    }
    await unmount(tester);
  });
}
