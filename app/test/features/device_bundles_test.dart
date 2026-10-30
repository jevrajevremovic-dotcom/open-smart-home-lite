import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_groups.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

const _fryer = 'Mi Smart Air Fryer (3.5L)';

SmartHomeDevice _d(String id, String name, DeviceKind kind, {String? dev}) =>
    SmartHomeDevice(
      id: id,
      sourceId: id,
      name: name,
      kind: kind,
      available: true,
      capabilities: const <Capability>{},
      state: const DeviceState(raw: 'on'),
      deviceId: dev,
    );

void main() {
  phoneGroups();
  test(
    'entities of one device become one bundle, named by what they share',
    () {
      final bundles = groupDevices([
        _d(
          'fx:button.a',
          '$_fryer Air Fryer Start',
          DeviceKind.button,
          dev: 'f',
        ),
        _d('fx:light.x', 'Lamp', DeviceKind.light),
        _d('fx:sensor.t', '$_fryer Time Left', DeviceKind.sensor, dev: 'f'),
        _d('fx:switch.p', '$_fryer Power', DeviceKind.switchDevice, dev: 'f'),
      ]);
      expect(bundles, hasLength(2));
      final fryer = bundles.first;
      expect(fryer.name, _fryer);
      expect(fryer.key, 'group:f');
      expect(fryer.primary.id, 'fx:switch.p');
      expect(fryer.shortName(fryer.members.first), 'Air Fryer Start');
      expect(bundles.last.isGroup, isFalse);
      expect(bundles.last.key, 'fx:light.x');
    },
  );

  testWidgets('kiosk: one card for the air fryer, its parts on the right', (
    tester,
  ) async {
    SmartHomeDevice part(
      String id,
      String name,
      DeviceKind kind,
      Set<Capability> capabilities,
      DeviceState state, {
      DeviceLimits limits = DeviceLimits.none,
    }) => fixtureDevice(
      id,
      name: '$_fryer $name',
      kind: kind,
      capabilities: capabilities,
      state: state,
      limits: limits,
      roomId: 'kitchen',
      deviceId: 'd_fryer',
      manufacturer: 'Xiaomi',
      model: 'MAF02',
    );
    final server = HomeFixture(
      devices: [
        ...fixtureDevices(DateTime.now()),
        part('switch.fryer', 'Power', DeviceKind.switchDevice, const {
          Capability.power,
        }, const DeviceState(raw: 'off', isOn: false)),
        part(
          'button.fryer_start',
          'Air Fryer Start',
          DeviceKind.button,
          const {},
          const DeviceState(raw: 'unknown'),
        ),
        part(
          'button.fryer_pause',
          'Air Fryer Pause',
          DeviceKind.button,
          const {},
          const DeviceState(raw: 'unknown'),
        ),
        part(
          'select.fryer_mode',
          'Mode',
          DeviceKind.select,
          const {Capability.selectOption},
          const DeviceState(raw: 'Pomfrit', textValue: 'Pomfrit'),
          limits: const DeviceLimits(options: ['Pomfrit', 'Piletina']),
        ),
        part(
          'number.fryer_temp',
          'Temperature',
          DeviceKind.number,
          const {Capability.numberValue},
          const DeviceState(raw: '180', numericValue: 180, unit: '°C'),
          limits: const DeviceLimits(minValue: 40, maxValue: 200, valueStep: 5),
        ),
        part(
          'sensor.fryer_time',
          'Time Left',
          DeviceKind.sensor,
          const {},
          const DeviceState(raw: '12', numericValue: 12, unit: 'min'),
        ),
      ],
    );
    await pumpApp(tester, adapter: server, size: const Size(1600, 1000));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);

    // One card, not six.
    expect(
      find.byKey(const ValueKey('kioskColumnsDevice-group:d_fryer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kioskColumnsDevice-fx:button.fryer_start')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsDevice-group:d_fryer')),
    );
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('kioskBundle-group:d_fryer')), findsOne);
    expect(
      find.byKey(const ValueKey('kioskBundleAction-fx:button.fryer_start')),
      findsOneWidget,
    );
    expect(find.text('Air Fryer Pause'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kioskBundleSetting-fx:select.fryer_mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kioskBundleState-fx:sensor.fryer_time')),
      findsOneWidget,
    );

    // Its main switch, from the card's round icon.
    expect(server.stateOf('fx:switch.fryer'), 'off');
    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsToggle-fx:switch.fryer')),
    );
    await settle(tester, 4);
    expect(server.stateOf('fx:switch.fryer'), 'on');
    await unmount(tester);
  });
}

void phoneGroups() {
  testWidgets('phone: a room shows the washer as one card, its parts inside', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('kitchen'));
    await settle(tester, 6);
    // One card for plug + power sensor, with the number of parts.
    expect(
      find.byKey(const ValueKey('tileGroupCount-d_washer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('group:d_washer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fx:sensor.washer_plug_power')),
      findsNothing,
    );
    expect(find.text('Veš mašina'), findsOneWidget);
    // Devices on their own stay as they were.
    expect(
      find.byKey(const ValueKey('fx:switch.coffee_machine')),
      findsOneWidget,
    );

    await tester.tap(find.text('Veš mašina'));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('kioskBundle-group:d_washer')), findsOne);
    expect(find.byKey(const Key('applianceDone')), findsOneWidget);
    // A part opens on its own screen (here: "tell me when it's done").
    await tester.tap(
      find.byKey(
        const ValueKey('kioskBundleState-fx:sensor.washer_plug_power'),
      ),
    );
    await settle(tester, 4);
    expect(find.byKey(const Key('applianceDone')), findsOneWidget);
    await unmount(tester);
  });
}
