import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/ha_backend.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/authentication/application/session_controller.dart';
import 'package:open_smart_home_lite/features/connection/application/connection_setup_controller.dart';
import 'package:open_smart_home_lite/features/devices/application/device_command_service.dart';
import 'package:open_smart_home_lite/features/devices/data/cache/snapshot_cache.dart';
import 'package:open_smart_home_lite/features/devices/data/cache/snapshot_cache_io.dart';
import 'package:open_smart_home_lite/features/devices/data/home_state_repository.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/api/home_assistant_api.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/backoff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

import '../helpers.dart';

const serverId = 'http://homeassistant.local:8123';

/// A cache built from the mock server's current data.
CachedHome cachedFrom(MockHomeAssistantServer server, DateTime syncedAt) =>
    CachedHome(
      savedAt: syncedAt,
      lastSyncedAt: syncedAt,
      states: server.states,
      areas: server.registries.areas,
      devices: server.registries.devices,
      entities: server.registries.entities,
      config: server.config,
    );

class SlowCache extends InMemorySnapshotCache {
  final Completer<void> release = Completer<void>();

  @override
  Future<CachedHome?> load(String serverId) async {
    await release.future;
    return super.load(serverId);
  }
}

class MockApi extends Mock implements HomeAssistantApi {}

void main() {
  group('CachedHome', () {
    test('JSON round-trip', () {
      final server = MockHomeAssistantServer();
      final home = cachedFrom(server, DateTime.utc(2026, 10, 13, 10));
      final back = CachedHome.tryFromJson(home.toJson())!;
      expect(back.lastSyncedAt, DateTime.utc(2026, 10, 13, 10));
      expect(back.states, hasLength(server.states.length));
    });

    test('unknown version or garbage is ignored, not fatal', () {
      expect(CachedHome.tryFromJson({'version': 99}), isNull);
      expect(CachedHome.tryFromJson('garbage'), isNull);
      expect(CachedHome.tryFromJson({'version': 1, 'states': 'x'}), isNull);
    });

    test('cached states map to the same devices as live ones', () {
      final server = MockHomeAssistantServer();
      final home = CachedHome.tryFromJson(
        cachedFrom(server, DateTime.now()).toJson(),
      )!;
      final registries = HaRegistries.parse(
        areas: home.areas,
        devices: home.devices,
        entities: home.entities,
      );
      final cached = const HaDeviceMapper().mapAll(
        parseStateList(home.states),
        registries,
      );
      final live = const HaDeviceMapper().mapAll(
        parseStateList(server.states),
        registries,
      );
      expect(cached.keys, live.keys);
      expect(cached['light.living_room_main']!.state.brightnessPercent, 75);
    });
  });

  group('FileSnapshotCache', () {
    late Directory dir;
    late FileSnapshotCache cache;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('osh_cache_test');
      cache = FileSnapshotCache(directory: () async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('save, load, clear', () async {
      final home = cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026));
      await cache.save(serverId, home);
      expect((await cache.load(serverId))!.lastSyncedAt, DateTime.utc(2026));
      await cache.clear(serverId);
      expect(await cache.load(serverId), isNull);
    });

    test(
      'file names do not reveal the server address; no temp files left',
      () async {
        await cache.save(
          serverId,
          cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026)),
        );
        final names = dir
            .listSync(recursive: true)
            .map((f) => f.path.split('/').last)
            .toList();
        expect(names.where((n) => n.contains('homeassistant')), isEmpty);
        expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
      },
    );

    test('corrupt file is ignored', () async {
      await cache.save(
        serverId,
        cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026)),
      );
      final file = dir.listSync(recursive: true).whereType<File>().single;
      file.writeAsStringSync('{not json');
      expect(await cache.load(serverId), isNull);
    });

    test('clear issued right after save always wins', () async {
      unawaited(
        cache.save(
          serverId,
          cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026)),
        ),
      );
      await cache.clear(serverId);
      expect(await cache.load(serverId), isNull);
    });
  });

  group('HomeStateRepository with cache', () {
    late MockHomeAssistantServer server;
    late HaWebSocketManager ws;
    late InMemorySnapshotCache cache;
    HomeStateRepository? repo;

    setUp(() {
      server = MockHomeAssistantServer();
      cache = InMemorySnapshotCache();
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
    });

    tearDown(() async {
      await repo?.dispose();
      await ws.dispose();
    });

    HomeStateRepository create({SnapshotCache? withCache}) =>
        repo = HomeStateRepository(
          ws,
          cache: withCache ?? cache,
          serverId: serverId,
          saveDelay: const Duration(milliseconds: 30),
        );

    Future<HomeSnapshot> waitFor(
      HomeStateRepository r,
      bool Function(HomeSnapshot) test,
    ) async {
      if (test(r.current)) return r.current;
      return r.snapshots.firstWhere(test).timeout(const Duration(seconds: 3));
    }

    test('live data is saved shortly after sync', () async {
      final r = create()..start();
      ws.connect();
      await waitFor(r, (s) => s.isLive);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final saved = await cache.load(serverId);
      expect(saved, isNotNull);
      expect(saved!.states, hasLength(server.states.length));
      expect((saved.config as Map)['location_name'], 'Demo dom (mock)');
    });

    test(
      'server offline at start: cached data shown, marked stale with its time',
      () async {
        final syncedAt = DateTime.utc(2026, 10, 12, 21, 30);
        await cache.save(serverId, cachedFrom(server, syncedAt));
        server.online = false;

        final r = create()..start();
        ws.connect();
        final s = await waitFor(r, (s) => s.hasData);
        expect(s.status, SyncStatus.stale);
        expect(s.isLive, isFalse);
        expect(s.lastSyncedAt, syncedAt);
        expect(s.rooms, isNotEmpty);
        expect(s.locationName, 'Demo dom (mock)');
        expect(s.devices['lock.front_door']!.roomId, 'hallway');
      },
    );

    test(
      'cached data is replaced by live data once the server is back',
      () async {
        await cache.save(serverId, cachedFrom(server, DateTime.utc(2026)));
        server.online = false;
        final r = create()..start();
        ws.connect();
        await waitFor(r, (s) => s.hasData);

        server.setStateForTest(
          'switch.coffee_machine',
          'on',
        ); // changed meanwhile
        server.online = true;
        final live = await waitFor(r, (s) => s.isLive);
        expect(live.devices['switch.coffee_machine']!.state.isOn, isTrue);
        expect(live.lastSyncedAt!.isAfter(DateTime.utc(2026)), isTrue);
      },
    );

    test('a slow cache never overwrites newer live data', () async {
      final slow = SlowCache();
      await slow.save(serverId, cachedFrom(server, DateTime.utc(2020)));
      final r = create(withCache: slow)..start();
      ws.connect();
      await waitFor(r, (s) => s.isLive);
      slow.release.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(r.current.isLive, isTrue);
      expect(r.current.lastSyncedAt!.year, isNot(2020));
    });

    test('dispose does not save; flush saves immediately', () async {
      final r = create()..start();
      ws.connect();
      await waitFor(r, (s) => s.isLive);
      await r.flush();
      expect(await cache.load(serverId), isNotNull);

      await cache.clear(serverId);
      server.setStateForTest('switch.coffee_machine', 'on');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await r.dispose();
      repo = null;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        await cache.load(serverId),
        isNull,
        reason: 'no write after dispose (sign-out)',
      );
    });
  });

  test('commands are refused while data is not live', () async {
    final api = MockApi();
    var online = false;
    final service = DeviceCommandService(
      HaCommandSink(api),
      isOnline: () => online,
    );
    final device = const HaDeviceMapper().map(
      const HaEntityState(entityId: 'switch.a', state: 'off', attributes: {}),
      HaRegistries.empty,
    );
    await expectLater(
      service.execute(device, const TurnOn()),
      throwsA(
        isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.network),
      ),
    );
    verifyNever(() => api.callService(any(), any(), data: any(named: 'data')));

    when(() => api.callService(any(), any(), data: any(named: 'data')))
        .thenAnswer((_) async => const []);
    online = true;
    await service.execute(device, const TurnOn());
    verify(
      () =>
          api.callService('switch', 'turn_on', data: {'entity_id': 'switch.a'}),
    ).called(1);
  });

  test('sign-out and data wipe delete the cache', () async {
    final cache = InMemorySnapshotCache();
    final c = ProviderContainer(
      overrides: await testOverrides(snapshotCache: cache),
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    final setup = c.read(connectionSetupControllerProvider.notifier);
    await setup.checkServer('homeassistant.local:8123');
    await setup.authenticate('token');

    await cache.save(
      serverId,
      cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026)),
    );
    await cache.save(
      'other',
      cachedFrom(MockHomeAssistantServer(), DateTime.utc(2026)),
    );
    await c.read(sessionControllerProvider.notifier).signOut();
    expect(await cache.load(serverId), isNull);
    expect(
      await cache.load('other'),
      isNotNull,
      reason: 'sign-out removes only this server',
    );

    await c.read(sessionControllerProvider.notifier).deleteAllLocalData();
    expect(cache.entries, isEmpty);
  });
}
