import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/devices/data/home_state_repository.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/backoff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/connection_status.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

void main() {
  late MockHomeAssistantServer server;
  late HaWebSocketManager ws;
  late HomeStateRepository repo;

  setUp(() {
    server = MockHomeAssistantServer();
    ws = HaWebSocketManager(
      uri: Uri.parse('ws://ha.local:8123/api/websocket'),
      readToken: () async => 'token',
      connector: server.connect,
      backoff: ExponentialBackoff(
        initial: const Duration(milliseconds: 10),
        max: const Duration(milliseconds: 40),
        random: Random(1),
      ),
    );
    repo = HomeStateRepository(
      ws,
      registryRefreshDelay: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    await repo.dispose();
    await ws.dispose();
  });

  Future<HomeSnapshot> waitFor(bool Function(HomeSnapshot s) test) async {
    if (test(repo.current)) return repo.current;
    return repo.snapshots.firstWhere(test).timeout(const Duration(seconds: 3));
  }

  Future<void> startLive() async {
    repo.start();
    ws.connect();
    await waitFor((s) => s.status == SyncStatus.live);
  }

  test('initial sync loads devices and rooms', () async {
    await startLive();
    final s = repo.current;
    expect(s.devices, hasLength(server.states.length));
    expect(s.rooms.keys, containsAll(['living_room', 'bedroom', 'hallway']));
    expect(s.devices['lock.front_door']!.roomId, 'hallway');
    expect(s.lastSyncedAt, isNotNull);
  });

  test('a state change re-maps only the affected device', () async {
    await startLive();
    final before = repo.current.devices;

    server.setStateForTest('switch.coffee_machine', 'on');
    final after = await waitFor(
      (s) => s.devices['switch.coffee_machine']!.state.isOn == true,
    );

    expect(
      identical(after.devices['light.hallway'], before['light.hallway']),
      isTrue,
    );
    expect(
      identical(
        after.devices['switch.coffee_machine'],
        before['switch.coffee_machine'],
      ),
      isFalse,
    );
  });

  test(
    'battery change updates the sibling entity of the same device',
    () async {
      await startLive();
      expect(
        repo
            .current
            .devices['binary_sensor.bedroom_window']!
            .metadata
            .batteryPercent,
        8,
      );

      server.setStateForTest('sensor.bedroom_window_battery', '95');
      final s = await waitFor(
        (s) =>
            s
                .devices['binary_sensor.bedroom_window']!
                .metadata
                .batteryPercent ==
            95,
      );
      expect(s.devices['binary_sensor.bedroom_window']!.hasLowBattery, isFalse);
    },
  );

  test('events during snapshot loading are not lost', () async {
    server.getStatesDelay = const Duration(milliseconds: 150);
    repo.start();
    ws.connect();
    await waitFor((s) => s.status == SyncStatus.syncing);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // Changed after the snapshot was taken but before it was delivered.
    server.setStateForTest('switch.coffee_machine', 'on');

    final s = await waitFor((s) => s.status == SyncStatus.live);
    expect(s.devices['switch.coffee_machine']!.state.isOn, isTrue);
  });

  test('connection loss keeps data marked stale; reconnect resyncs', () async {
    await startLive();
    await server.dropAllConnections();
    final stale = await waitFor((s) => s.status == SyncStatus.stale);
    expect(stale.devices, isNotEmpty, reason: 'last known data stays visible');

    // Changed while we were offline.
    server.setStateForTest('switch.coffee_machine', 'on');
    final live = await waitFor((s) => s.status == SyncStatus.live);
    expect(live.devices['switch.coffee_machine']!.state.isOn, isTrue);
    expect(ws.status.state, HaConnectionState.connected);
  });

  test('registry update events trigger a registry refresh', () async {
    await startLive();
    final roomsBefore = repo.current.rooms.length;
    server.registries.areas.add({'area_id': 'office', 'name': 'Kancelarija'});
    server.fireEvent('area_registry_updated', {
      'action': 'create',
      'area_id': 'office',
    });

    final s = await waitFor((s) => s.rooms.containsKey('office'));
    expect(s.rooms.length, roomsBefore + 1);
  });

  test('works without registries (restricted user / old server)', () async {
    server.registries.areas.clear();
    server.registries.devices.clear();
    server.registries.entities.clear();
    await startLive();
    expect(repo.current.rooms, isEmpty);
    expect(repo.current.devices, isNotEmpty);
    expect(repo.current.devices['lock.front_door']!.roomId, isNull);
  });

  test('dispose cancels subscriptions', () async {
    await startLive();
    await repo.dispose();
    await pumpEventQueue(times: 20);
    expect(ws.activeServerSubscriptions, 0);
    repo = HomeStateRepository(ws); // for tearDown
  });
}
