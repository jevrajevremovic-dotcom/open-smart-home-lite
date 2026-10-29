import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/dashboard/application/home_summaries.dart';
import 'package:open_smart_home_lite/features/devices/data/home_state_repository.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/backoff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

/// A synthetic large home: [entityCount] entities on [entityCount]/10
/// devices in 20 areas. Mix: 30 % lights, 20 % switches, 40 % sensors
/// (+ a battery sensor per device), 10 % binary sensors.
({
  List<Map<String, Object?>> states,
  ({
    List<Map<String, Object?>> areas,
    List<Map<String, Object?>> devices,
    List<Map<String, Object?>> entities,
  })
  registries,
})
largeHome(int entityCount) {
  final now = DateTime.now().toUtc().toIso8601String();
  final states = <Map<String, Object?>>[];
  final entities = <Map<String, Object?>>[];
  final devices = <Map<String, Object?>>[];
  final areas = [
    for (var a = 0; a < 20; a++) {'area_id': 'area_$a', 'name': 'Room $a'},
  ];
  for (var i = 0; i < entityCount; i++) {
    final deviceId = 'dev_${i ~/ 10}';
    if (i % 10 == 0) {
      devices.add({
        'id': deviceId,
        'name': 'Device ${i ~/ 10}',
        'manufacturer': 'Acme',
        'model': 'M${i % 7}',
        'area_id': 'area_${(i ~/ 10) % 20}',
        'identifiers': [
          ['zha', 'ieee_$i'],
        ],
      });
      final batteryId = 'sensor.battery_${i ~/ 10}';
      states.add({
        'entity_id': batteryId,
        'state': '${50 + i % 50}',
        'attributes': {'device_class': 'battery', 'unit_of_measurement': '%'},
        'last_changed': now,
        'last_updated': now,
      });
      entities.add({
        'entity_id': batteryId,
        'device_id': deviceId,
        'platform': 'zha',
        'entity_category': 'diagnostic',
      });
    }
    final (String id, String state, Map<String, Object?> attrs) = switch (i %
        10) {
      0 || 1 || 2 => (
        'light.l_$i',
        'on',
        {
          'supported_color_modes': ['color_temp'],
          'brightness': 128,
          'color_temp_kelvin': 3000,
          'friendly_name': 'Light $i',
        },
      ),
      3 || 4 => ('switch.s_$i', 'off', {'friendly_name': 'Switch $i'}),
      5 || 6 || 7 || 8 => (
        'sensor.t_$i',
        '21.5',
        {
          'device_class': 'temperature',
          'unit_of_measurement': '°C',
          'friendly_name': 'Temp $i',
        },
      ),
      _ => (
        'binary_sensor.d_$i',
        'off',
        {'device_class': 'door', 'friendly_name': 'Door $i'},
      ),
    };
    states.add({
      'entity_id': id,
      'state': state,
      'attributes': attrs,
      'last_changed': now,
      'last_updated': now,
    });
    entities.add({'entity_id': id, 'device_id': deviceId, 'platform': 'zha'});
  }
  return (
    states: states,
    registries: (areas: areas, devices: devices, entities: entities),
  );
}

void main() {
  const n = 2000;
  final home = largeHome(n);

  test('mapping $n entities is fast', () {
    final registries = HaRegistries.parse(
      areas: home.registries.areas,
      devices: home.registries.devices,
      entities: home.registries.entities,
    );
    final states = parseStateList(home.states);
    final sw = Stopwatch()..start();
    final devices = const HaDeviceMapper().mapAll(states, registries);
    sw.stop();
    debugPrint('mapAll(${states.length}): ${sw.elapsedMilliseconds} ms');
    expect(devices.length, states.length);
    expect(
      sw.elapsedMilliseconds,
      lessThan(1500),
    ); // generous: debug VM, CI machines

    final sw2 = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      summarize(devices.values);
    }
    debugPrint('summarize x20: ${sw2.elapsedMilliseconds} ms');
    expect(sw2.elapsedMilliseconds, lessThan(1500));
  });

  test('sync + burst of $n state changes', () async {
    final server = MockHomeAssistantServer(
      states: home.states,
      registries: home.registries,
    );
    final ws = HaWebSocketManager(
      uri: Uri.parse('ws://ha.local/api/websocket'),
      readToken: () async => 't',
      connector: server.connect,
      backoff: ExponentialBackoff(random: Random(1)),
    );
    final repo = HomeStateRepository(ws);
    addTearDown(() async {
      await repo.dispose();
      await ws.dispose();
    });

    var emissions = 0;
    repo.snapshots.listen((_) => emissions++);
    final sync = Stopwatch()..start();
    repo.start();
    ws.connect();
    await repo.snapshots
        .firstWhere((s) => s.isLive)
        .timeout(const Duration(seconds: 20));
    sync.stop();
    debugPrint(
      'initial sync of ${home.states.length} entities: ${sync.elapsedMilliseconds} ms',
    );

    emissions = 0;
    final burst = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      server.setStateForTest(
        'sensor.t_${(i * 10) % n + 5}',
        '${20 + (i % 50) / 10}',
      );
    }
    // Events are processed in order: once this marker is visible, every
    // earlier change has been applied too.
    server.setStateForTest('switch.s_3', 'on');
    await repo.snapshots
        .firstWhere((s) => s.devices['switch.s_3']!.state.isOn == true)
        .timeout(const Duration(seconds: 30));
    burst.stop();
    debugPrint(
      '$n events: ${burst.elapsedMilliseconds} ms, $emissions snapshot emissions',
    );
    expect(burst.elapsedMilliseconds, lessThan(10000));
    // Events are coalesced: a burst must not produce one UI update per event.
    expect(emissions, lessThan(n ~/ 20));
    expect(repo.current.devices['sensor.t_1995']!.state.numericValue, 24.9);
  });
}
