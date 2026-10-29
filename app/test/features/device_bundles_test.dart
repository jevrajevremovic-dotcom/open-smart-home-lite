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
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

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
        _d('button.a', '$_fryer Air Fryer Start', DeviceKind.button, dev: 'f'),
        _d('light.x', 'Lamp', DeviceKind.light),
        _d('sensor.t', '$_fryer Time Left', DeviceKind.sensor, dev: 'f'),
        _d('switch.p', '$_fryer Power', DeviceKind.switchDevice, dev: 'f'),
      ]);
      expect(bundles, hasLength(2));
      final fryer = bundles.first;
      expect(fryer.name, _fryer);
      expect(fryer.key, 'group:f');
      expect(fryer.primary.id, 'switch.p');
      expect(fryer.shortName(fryer.members.first), 'Air Fryer Start');
      expect(bundles.last.isGroup, isFalse);
      expect(bundles.last.key, 'light.x');
    },
  );

  testWidgets('kiosk: one card for the air fryer, its parts on the right', (
    tester,
  ) async {
    final now = DateTime.now();
    String ts() => now.toUtc().toIso8601String();
    Map<String, Object?> state(
      String id,
      String state,
      String name, [
      Map<String, Object?> more = const {},
    ]) => {
      'entity_id': id,
      'state': state,
      'attributes': {'friendly_name': '$_fryer $name', ...more},
      'last_changed': ts(),
      'last_updated': ts(),
    };
    Map<String, Object?> entity(String id) => {
      'entity_id': id,
      'platform': 'xiaomi_miot',
      'device_id': 'd_fryer',
      'area_id': null,
      'entity_category': null,
      'hidden_by': null,
      'disabled_by': null,
    };
    final base = buildMockRegistries();
    final ids = [
      'switch.fryer',
      'button.fryer_start',
      'button.fryer_pause',
      'select.fryer_mode',
      'number.fryer_temp',
      'sensor.fryer_time',
    ];
    final server = MockHomeAssistantServer(
      states: [
        ...buildMockStates(now),
        state('switch.fryer', 'off', 'Power'),
        state('button.fryer_start', 'unknown', 'Air Fryer Start'),
        state('button.fryer_pause', 'unknown', 'Air Fryer Pause'),
        state('select.fryer_mode', 'Pomfrit', 'Mode', {
          'options': ['Pomfrit', 'Piletina'],
        }),
        state('number.fryer_temp', '180', 'Temperature', {
          'min': 40,
          'max': 200,
          'step': 5,
          'unit_of_measurement': '°C',
        }),
        state('sensor.fryer_time', '12', 'Time Left', {
          'unit_of_measurement': 'min',
        }),
      ],
      registries: (
        areas: base.areas,
        devices: [
          ...base.devices,
          {
            'id': 'd_fryer',
            'name': _fryer,
            'name_by_user': null,
            'manufacturer': 'Xiaomi',
            'model': 'MAF02',
            'area_id': 'kitchen',
            'identifiers': [
              ['xiaomi_miot', 'fryer'],
            ],
            'via_device_id': null,
          },
        ],
        entities: [...base.entities, for (final id in ids) entity(id)],
      ),
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1600, 1000),
      server: server,
    );
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
      find.byKey(const ValueKey('kioskColumnsDevice-button.fryer_start')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsDevice-group:d_fryer')),
    );
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('kioskBundle-group:d_fryer')), findsOne);
    expect(
      find.byKey(const ValueKey('kioskBundleAction-button.fryer_start')),
      findsOneWidget,
    );
    expect(find.text('Air Fryer Pause'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kioskBundleSetting-select.fryer_mode')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kioskBundleState-sensor.fryer_time')),
      findsOneWidget,
    );

    // Its main switch, from the card's round icon.
    expect(server.stateForTest('switch.fryer'), 'off');
    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsToggle-switch.fryer')),
    );
    await settle(tester, 4);
    expect(server.stateForTest('switch.fryer'), 'on');
    await unmount(tester);
  });
}

void phoneGroups() {
  testWidgets('phone: a room shows the washer as one card, its parts inside', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
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
      find.byKey(const ValueKey('sensor.washer_plug_power')),
      findsNothing,
    );
    expect(find.text('Veš mašina'), findsOneWidget);
    // Devices on their own stay as they were.
    expect(find.byKey(const ValueKey('switch.coffee_machine')), findsOneWidget);

    await tester.tap(find.text('Veš mašina'));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('kioskBundle-group:d_washer')), findsOne);
    expect(find.byKey(const Key('applianceDone')), findsOneWidget);
    // A part opens on its own screen (here: "tell me when it's done").
    await tester.tap(
      find.byKey(const ValueKey('kioskBundleState-sensor.washer_plug_power')),
    );
    await settle(tester, 4);
    expect(find.byKey(const Key('applianceDone')), findsOneWidget);
    await unmount(tester);
  });
}
