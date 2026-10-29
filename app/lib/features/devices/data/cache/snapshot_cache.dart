import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'snapshot_cache_io.dart'
    if (dart.library.js_interop) 'snapshot_cache_web.dart';

/// Last known Home Assistant data for one server, in HA wire format.
///
/// Raw data (not mapped devices) is cached on purpose: on load it goes
/// through the same mapper as live data, so a mapper improvement never has
/// to migrate a cache.
@immutable
class CachedHome {
  const CachedHome({
    required this.savedAt,
    required this.lastSyncedAt,
    required this.states,
    this.areas,
    this.devices,
    this.entities,
    this.floors,
    this.config,
  });

  static const int schemaVersion = 1;

  /// Returns `null` for unknown versions or malformed data, so a broken
  /// cache is ignored instead of breaking start-up.
  static CachedHome? tryFromJson(Object? json) {
    if (json is! Map<String, Object?> || json['version'] != schemaVersion) {
      return null;
    }
    final states = json['states'];
    final synced = json['lastSyncedAt'];
    final saved = json['savedAt'];
    if (states is! List || synced is! String || saved is! String) return null;
    final registries = json['registries'];
    final reg = registries is Map ? registries : const {};
    final lastSyncedAt = DateTime.tryParse(synced);
    final savedAt = DateTime.tryParse(saved);
    if (lastSyncedAt == null || savedAt == null) return null;
    return CachedHome(
      savedAt: savedAt,
      lastSyncedAt: lastSyncedAt,
      states: states,
      areas: reg['areas'],
      devices: reg['devices'],
      entities: reg['entities'],
      floors: reg['floors'],
      config: json['config'],
    );
  }

  final DateTime savedAt;

  /// When this data was last confirmed live by the server.
  final DateTime lastSyncedAt;
  final List<Object?> states;
  final Object? areas;
  final Object? devices;
  final Object? entities;
  final Object? floors;
  final Object? config;

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'lastSyncedAt': lastSyncedAt.toUtc().toIso8601String(),
    'states': states,
    'registries': {
      'areas': areas,
      'devices': devices,
      'entities': entities,
      'floors': floors,
    },
    'config': config,
  };
}

/// Persistence for [CachedHome], one entry per server.
abstract interface class SnapshotCache {
  Future<CachedHome?> load(String serverId);
  Future<void> save(String serverId, CachedHome home);
  Future<void> clear(String serverId);
  Future<void> clearAll();
}

/// Runs operations one after another, so a `clear` issued during sign-out
/// can never be overtaken by a `save` that started earlier.
mixin SerializedOperations {
  Future<void> _tail = Future.value();

  Future<T> serialized<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}

class InMemorySnapshotCache with SerializedOperations implements SnapshotCache {
  final Map<String, Map<String, Object?>> entries = {};

  @override
  Future<CachedHome?> load(String serverId) =>
      serialized(() async => CachedHome.tryFromJson(entries[serverId]));

  @override
  Future<void> save(String serverId, CachedHome home) =>
      serialized(() async => entries[serverId] = home.toJson());

  @override
  Future<void> clear(String serverId) =>
      serialized(() async => entries.remove(serverId));

  @override
  Future<void> clearAll() => serialized(() async => entries.clear());
}

final snapshotCacheProvider = Provider<SnapshotCache>(
  (ref) => createPlatformSnapshotCache(),
);
