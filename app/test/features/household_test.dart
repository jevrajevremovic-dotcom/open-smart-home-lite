import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/household/application/household_providers.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('members are kept with the home and shown as people', () {
    const home = LocalHome(
      members: [HouseholdMember(id: 'a1', name: 'Ana')],
    );
    expect(LocalHome.fromJson(home.toJson()).members, home.members);
    final backend = LocalBackend(const [], home: home)..start();
    addTearDown(backend.dispose);
    final ana = backend.current.devices['member:a1']!;
    expect(
      (ana.kind, ana.name, ana.state.raw),
      (DeviceKind.person, 'Ana', 'member'),
    );
  });

  testWidgets('a member added in Settings → Kiosk gets a PIN button', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(800, 1600));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await settle(tester, 2);
    await tapKey(tester, 'householdAdd');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('householdName')), 'Marko');
    await tapKey(tester, 'householdNameOk');
    await settle(tester, 4);
    final id = container.read(peopleIdsProvider).single;
    expect(container.read(deviceProvider(id))?.name, 'Marko');
    expect(find.byKey(ValueKey('kioskPersonSetPin-$id')), findsOneWidget);

    await tapKey(tester, 'householdRemove-$id');
    await settle(tester, 4);
    expect(container.read(peopleIdsProvider), isEmpty);
    await unmount(tester);
  });
}
