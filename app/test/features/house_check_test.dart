import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/house_check/house_check.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  SmartHomeDevice d(
    String id,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state, {
    bool available = true,
  }) => fixtureDevice(
    id,
    name: id,
    kind: kind,
    capabilities: capabilities,
    state: state,
    available: available,
  );

  final devices = [
    d('light.kitchen', DeviceKind.light, const {
      Capability.power,
    }, const DeviceState(raw: 'on', isOn: true)),
    d('light.hall', DeviceKind.light, const {
      Capability.power,
    }, const DeviceState(raw: 'off', isOn: false)),
    d('lock.front', DeviceKind.lock, const {
      Capability.lock,
      Capability.unlock,
    }, const DeviceState(raw: 'unlocked', lockState: DoorLockState.unlocked)),
    d(
      'binary_sensor.window',
      DeviceKind.contactSensor,
      const {},
      const DeviceState(raw: 'on', isActive: true),
    ),
    d('cover.garage', DeviceKind.garageDoor, const {
      Capability.open,
      Capability.close,
    }, const DeviceState(raw: 'open', coverState: CoverState.open)),
    d('climate.living', DeviceKind.climate, const {
      Capability.power,
      Capability.hvacMode,
    }, const DeviceState(raw: 'heat', isOn: true, hvacMode: 'heat')),
    // Plays, but cannot be turned off from here.
    d('media_player.tv', DeviceKind.television, const {
      Capability.mediaPause,
    }, const DeviceState(raw: 'playing', isOn: true)),
    d(
      'light.offline',
      DeviceKind.light,
      const {Capability.power},
      const DeviceState(raw: 'unavailable'),
      available: false,
    ),
  ];

  test('leaving: security first, lights last; fixes where possible', () {
    final items = houseCheck(devices, HouseCheckMode.leaving);
    expect(
      [for (final i in items) i.device.id],
      [
        'fx:binary_sensor.window',
        'fx:cover.garage',
        'fx:lock.front',
        'fx:climate.living',
        'fx:media_player.tv',
        'fx:light.kitchen',
      ],
    );
    final fixes = {for (final i in items) i.device.id: i.fix};
    expect(fixes['fx:binary_sensor.window'], isNull, reason: 'cannot close it');
    expect(fixes['fx:cover.garage'], isA<CloseCover>());
    expect(fixes['fx:lock.front'], isA<LockDevice>());
    expect(fixes['fx:light.kitchen'], isA<TurnOff>());
  });

  test('night keeps the heating running', () {
    final items = houseCheck(devices, HouseCheckMode.night);
    expect(items.map((i) => i.device.id), isNot(contains('fx:climate.living')));
    expect(items.map((i) => i.device.id), contains('fx:lock.front'));
  });

  test('the mode follows the time of day', () {
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 9)),
      HouseCheckMode.leaving,
    );
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 22)),
      HouseCheckMode.night,
    );
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 2)),
      HouseCheckMode.night,
    );
  });

  testWidgets('fix everything the app can before leaving', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1400));
    await settle(tester, 10);
    await tapKey(tester, 'openHouseCheck');
    await settle(tester, 4);
    await goTo(tester, AppRoutes.houseCheckFor('leaving'));
    await settle(tester, 4);

    for (final id in [
      'fx:light.living_room_main',
      'fx:light.living_room_ambient',
      'fx:climate.living_room',
      'fx:media_player.living_room_speaker',
      'fx:humidifier.bedroom',
      'fx:alarm_control_panel.home_alarm',
    ]) {
      expect(
        find.byKey(ValueKey('houseCheck-$id')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(
      find.byKey(
        const ValueKey('houseCheckOpen-fx:alarm_control_panel.home_alarm'),
      ),
      findsOneWidget,
      reason: 'the alarm needs its own screen (code)',
    );

    await tapKey(tester, 'houseCheckFixAll');
    await settle(tester, 20);
    final server = HomeFixture.running;
    String? state(String id) => server.stateOf(id);
    expect(state('fx:light.living_room_main'), 'off');
    expect(state('fx:light.living_room_ambient'), 'off');
    expect(state('fx:climate.living_room'), 'off');
    expect(state('fx:media_player.living_room_speaker'), 'off');
    expect(state('fx:humidifier.bedroom'), 'off');
    expect(find.byKey(const Key('houseCheckFixAll')), findsNothing);
    expect(
      find.byKey(
        const ValueKey('houseCheck-fx:alarm_control_panel.home_alarm'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
