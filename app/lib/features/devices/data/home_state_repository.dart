import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../integrations/home_assistant/mappers/ha_device_mapper.dart';
import '../../../integrations/home_assistant/models/ha_models.dart';
import '../../../integrations/home_assistant/models/ha_registry.dart';
import '../../../integrations/home_assistant/websocket/connection_status.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';
import '../domain/home_snapshot.dart';
import '../domain/smart_home_device.dart';
import 'cache/snapshot_cache.dart';

export '../domain/home_snapshot.dart';

/// Keeps a consistent, live picture of the home.
///
/// Synchronisation (repeated after every reconnect):
/// 1. `state_changed` subscription is active before anything is loaded
///    (the WebSocket manager re-subscribes right after `auth_ok`);
/// 2. registries and `get_states` are fetched over the same socket, so the
///    snapshot is taken *after* the subscription started;
/// 3. events that arrived during loading are applied on top, skipping any
///    older than the snapshot's `last_updated`.
///
/// After that each event re-maps only the affected entity (or all entities
/// of its device when a battery/signal reading changed). Unchanged devices
/// keep their object identity, so UI widgets watching them do not rebuild.
///
/// Offline cache: on start the last saved snapshot (if any) is shown at
/// once with status [SyncStatus.stale] and its original sync time, until
/// live data replaces it. Live data is saved [saveDelay] after the last
/// change and on [flush] (e.g. when the app goes to the background).
class HomeStateRepository {
  HomeStateRepository(
    this._ws, {
    this._mapper = const HaDeviceMapper(),
    this.registryRefreshDelay = const Duration(milliseconds: 500),
    this._cache,
    this._serverId,
    this.saveDelay = const Duration(seconds: 3),
    this.eventCoalescing = const Duration(milliseconds: 50),
  });

  final HaWebSocketManager _ws;
  final HaDeviceMapper _mapper;
  final Duration registryRefreshDelay;
  final SnapshotCache? _cache;
  final String? _serverId;
  final Duration saveDelay;

  /// Maximum delay between a state event and its snapshot emission.
  final Duration eventCoalescing;
  static final _log = AppLogger('HomeState');

  static const _registryEvents = [
    'area_registry_updated',
    'device_registry_updated',
    'entity_registry_updated',
    'floor_registry_updated',
  ];

  final StreamController<HomeSnapshot> _controller =
      StreamController<HomeSnapshot>.broadcast();
  HomeSnapshot _snapshot = HomeSnapshot.empty;

  final Map<String, HaEntityState> _states = {};
  HaRegistries _registries = HaRegistries.empty;

  /// Registry and config responses as received, for the cache.
  ({Object? areas, Object? devices, Object? entities, Object? floors})
  _rawRegistries = (areas: null, devices: null, entities: null, floors: null);
  Object? _rawConfig;
  bool _hasLiveData = false;
  bool _dirty = false;
  bool _disposed = false;
  Timer? _saveTimer;
  Timer? _coalesceTimer;

  /// Devices changed by events but not yet emitted.
  Map<String, SmartHomeDevice>? _working;
  Map<String, DeviceAuxiliaryInfo> _aux = const {};

  /// Non-null while a snapshot is loading; events are queued here.
  List<HaStateChangedEvent>? _pending;
  int _syncGeneration = 0;
  Timer? _registryTimer;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _started = false;

  HomeSnapshot get current => _snapshot;
  Stream<HomeSnapshot> get snapshots => _controller.stream;

  void start() {
    if (_started) return;
    _started = true;
    _subscriptions
      ..add(_ws.stateChanges().listen(_onStateChanged))
      ..addAll(
        _registryEvents.map(
          (type) => _ws.events(type).listen((_) => _scheduleRegistryRefresh()),
        ),
      )
      ..add(_ws.statusStream.listen(_onConnectionStatus));
    _onConnectionStatus(_ws.status);
    unawaited(_loadCache());
  }

  /// Saves pending changes now (call when the app goes to the background).
  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_dirty) await _save();
  }

  /// Stops all work. Does not save: on sign-out the cache is deleted right
  /// after, and a late write must not bring the data back.
  Future<void> dispose() async {
    _disposed = true;
    _saveTimer?.cancel();
    _coalesceTimer?.cancel();
    _registryTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _controller.close();
  }

  // ---------------------------------------------------------------------------

  void _onConnectionStatus(HaConnectionStatus status) {
    if (status.isConnected) {
      if (_snapshot.status != SyncStatus.syncing &&
          _snapshot.status != SyncStatus.live) {
        unawaited(_resync());
      }
    } else if (_snapshot.status == SyncStatus.live ||
        _snapshot.status == SyncStatus.syncing) {
      _flushWorking(); // keep the last received changes visible
      _syncGeneration++; // abandon an in-flight sync
      _pending = null;
      _emit(
        _snapshot.copyWith(
          status: _snapshot.hasData ? SyncStatus.stale : SyncStatus.initial,
        ),
      );
    }
  }

  Future<void> _resync() async {
    final generation = ++_syncGeneration;
    _pending = [];
    _emit(_snapshot.copyWith(status: SyncStatus.syncing, clearFailure: true));
    try {
      final (registries, statesJson, config) = await (
        _loadRegistries(),
        _ws.sendCommand({'type': 'get_states'}),
        _optional('get_config'),
      ).wait;
      if (generation != _syncGeneration) return;

      _registries = registries;
      _rawConfig = config ?? _rawConfig;
      _states
        ..clear()
        ..addEntries(
          parseStateList(
            statesJson,
            onSkipped: (e) => _log.warning('Skipped malformed state', e),
          ).map((s) => MapEntry(s.entityId, s)),
        );
      final queued = _pending ?? const [];
      _pending = null;
      for (final event in queued) {
        _applyToStates(event);
      }
      _hasLiveData = true;
      _remapAll(status: SyncStatus.live);
      _scheduleSave();
      _log.info(
        'Synced ${_states.length} entities, ${_registries.areas.length} areas',
      );
    } on Object catch (e) {
      if (generation != _syncGeneration) return;
      _pending = null;
      final failure = e is AppFailure
          ? e
          : AppFailure(
              FailureKind.parsing,
              debugMessage: 'sync failed: ${e.runtimeType}',
            );
      if (e is ParallelWaitError) _log.warning('Sync failed', e.errors);
      _log.warning('Sync failed', failure);
      _emit(
        _snapshot.copyWith(
          status: _snapshot.hasData ? SyncStatus.stale : SyncStatus.initial,
          failure: failure,
        ),
      );
    }
  }

  /// Registries are optional: on failure (older server, restricted user)
  /// the app continues without rooms and protocol information.
  Future<HaRegistries> _loadRegistries() async {
    final (areas, devices, entities, floors) = await (
      _optional('config/area_registry/list'),
      _optional('config/device_registry/list'),
      _optional('config/entity_registry/list'),
      _optional('config/floor_registry/list'),
    ).wait;
    _rawRegistries = (
      areas: areas,
      devices: devices,
      entities: entities,
      floors: floors,
    );
    return HaRegistries.parse(
      areas: areas,
      devices: devices,
      entities: entities,
      floors: floors,
    );
  }

  Future<Object?> _optional(String type) async {
    try {
      return await _ws.sendCommand({'type': type});
    } on AppFailure catch (e) {
      _log.warning('$type unavailable', e);
      return null;
    }
  }

  void _scheduleRegistryRefresh() {
    _registryTimer?.cancel();
    _registryTimer = Timer(registryRefreshDelay, () async {
      if (_snapshot.status != SyncStatus.live) return;
      final generation = _syncGeneration;
      final registries = await _loadRegistries();
      if (generation != _syncGeneration) return;
      _registries = registries;
      _remapAll(status: SyncStatus.live);
      _scheduleSave();
    });
  }

  void _onStateChanged(HaStateChangedEvent event) {
    final pending = _pending;
    if (pending != null) {
      pending.add(event);
      return;
    }
    if (_snapshot.status != SyncStatus.live) return;
    if (!_applyToStates(event)) return;

    final newState = event.newState;
    final deviceId = _registries.entities[event.entityId]?.deviceId;
    final auxChanged =
        deviceId != null &&
        ((newState != null && _mapper.isAuxiliarySource(newState)) ||
            (event.oldState != null &&
                _mapper.isAuxiliarySource(event.oldState!)));
    if (auxChanged) {
      _aux = _mapper.collectAuxiliaryInfo(_states.values, _registries);
    }

    final devices = _working ??= Map<String, SmartHomeDevice>.of(
      _snapshot.devices,
    );
    if (newState == null) {
      devices.remove(event.entityId);
    }
    final affected = auxChanged
        ? _states.values.where(
            (s) => _registries.entities[s.entityId]?.deviceId == deviceId,
          )
        : [?newState];
    for (final state in affected) {
      _mapInto(devices, state);
    }
    // Coalesce bursts (many sensors reporting at once) into one snapshot
    // per [eventCoalescing] window, bounding UI recomputation.
    _coalesceTimer ??= Timer(eventCoalescing, _flushWorking);
    _scheduleSave();
  }

  /// Publishes event changes collected in [_working].
  void _flushWorking() {
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    final devices = _working;
    _working = null;
    if (devices == null || _disposed) return;
    _emit(
      _snapshot.copyWith(
        devices: Map.unmodifiable(devices),
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  /// Returns `false` when the event is older than what is already known.
  bool _applyToStates(HaStateChangedEvent event) {
    final next = event.newState;
    if (next == null) {
      return _states.remove(event.entityId) != null;
    }
    final known = _states[event.entityId]?.lastUpdated;
    final incoming = next.lastUpdated;
    if (known != null && incoming != null && incoming.isBefore(known)) {
      return false;
    }
    _states[event.entityId] = next;
    return true;
  }

  void _remapAll({required SyncStatus status, DateTime? syncedAt}) {
    // A full re-map supersedes pending event changes (they are in _states).
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _working = null;
    _aux = _mapper.collectAuxiliaryInfo(_states.values, _registries);
    final devices = _mapper.mapAll(
      _states.values,
      _registries,
      onError: (id, e) => _log.warning('Could not map $id', e),
    );
    final rooms = {
      for (final area in _registries.areas.values)
        area.id: Room(
          id: area.id,
          name: area.name,
          icon: area.icon,
          picture: area.picture,
          floorName: _registries.floors[area.floorId]?.name,
          floorLevel: _registries.floors[area.floorId]?.level,
        ),
    };
    _emit(
      _snapshot.copyWith(
        devices: Map.unmodifiable(devices),
        rooms: Map.unmodifiable(rooms),
        status: status,
        lastSyncedAt: syncedAt ?? DateTime.now(),
        locationName: _locationName(_rawConfig),
        clearFailure: true,
      ),
    );
  }

  static String? _locationName(Object? config) {
    if (config == null) return null;
    try {
      return HaConfig.fromJson(config).locationName;
    } on AppFailure {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Offline cache

  Future<void> _loadCache() async {
    final cache = _cache;
    final serverId = _serverId;
    if (cache == null || serverId == null) return;
    final cached = await cache.load(serverId);
    // Live data may have arrived while the cache was being read.
    if (cached == null || _hasLiveData || _disposed) return;

    _registries = HaRegistries.parse(
      areas: cached.areas,
      devices: cached.devices,
      entities: cached.entities,
      floors: cached.floors,
    );
    _rawRegistries = (
      areas: cached.areas,
      devices: cached.devices,
      entities: cached.entities,
      floors: cached.floors,
    );
    _rawConfig = cached.config;
    _states
      ..clear()
      ..addEntries(
        parseStateList(cached.states).map((s) => MapEntry(s.entityId, s)),
      );
    // Keep "syncing" if a sync is already running; the data is not current
    // either way and is marked with its original sync time.
    _remapAll(
      status: _snapshot.status == SyncStatus.syncing
          ? SyncStatus.syncing
          : SyncStatus.stale,
      syncedAt: cached.lastSyncedAt,
    );
    _log.info(
      'Showing cached data from ${cached.lastSyncedAt.toIso8601String()}',
    );
  }

  void _scheduleSave() {
    if (_cache == null || _serverId == null || _disposed) return;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(_save()));
  }

  Future<void> _save() async {
    final cache = _cache;
    final serverId = _serverId;
    final syncedAt = _snapshot.lastSyncedAt;
    if (cache == null ||
        serverId == null ||
        syncedAt == null ||
        !_hasLiveData ||
        _disposed) {
      return;
    }
    _dirty = false;
    await cache.save(
      serverId,
      CachedHome(
        savedAt: DateTime.now(),
        lastSyncedAt: syncedAt,
        states: [for (final s in _states.values) s.toJson()],
        areas: _rawRegistries.areas,
        devices: _rawRegistries.devices,
        entities: _rawRegistries.entities,
        floors: _rawRegistries.floors,
        config: _rawConfig,
      ),
    );
  }

  void _mapInto(Map<String, SmartHomeDevice> devices, HaEntityState state) {
    if (_registries.entities[state.entityId]?.disabled ?? false) return;
    try {
      devices[state.entityId] = _mapper.map(state, _registries, _aux);
    } on Object catch (e) {
      _log.warning('Could not map ${state.entityId}', e);
    }
  }

  void _emit(HomeSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}
