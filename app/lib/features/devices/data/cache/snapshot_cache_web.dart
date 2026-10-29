import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../../../core/logging/app_logger.dart';
import 'snapshot_cache.dart';

SnapshotCache createPlatformSnapshotCache() => SessionStorageSnapshotCache();

/// Browser cache in the tab's `sessionStorage`, matching where the token
/// lives: home data (presence, locks, alarms) never stays on a shared
/// computer after the tab is closed. Quota errors only disable caching.
class SessionStorageSnapshotCache
    with SerializedOperations
    implements SnapshotCache {
  static const _prefix = 'home_cache::';
  static final _log = AppLogger('SnapshotCache');

  web.Storage get _storage => web.window.sessionStorage;

  @override
  Future<CachedHome?> load(String serverId) => serialized(() async {
    try {
      final raw = _storage.getItem('$_prefix$serverId');
      return raw == null ? null : CachedHome.tryFromJson(jsonDecode(raw));
    } on Object catch (e) {
      _log.warning('Ignoring unreadable cache', e.runtimeType);
      return null;
    }
  });

  @override
  Future<void> save(String serverId, CachedHome home) => serialized(() async {
    try {
      _storage.setItem('$_prefix$serverId', jsonEncode(home.toJson()));
    } on Object catch (e) {
      _log.warning('Could not write cache (quota?)', e.runtimeType);
    }
  });

  @override
  Future<void> clear(String serverId) =>
      serialized(() async => _storage.removeItem('$_prefix$serverId'));

  @override
  Future<void> clearAll() => serialized(() async {
    final keys = [for (var i = 0; i < _storage.length; i++) _storage.key(i)]
        .whereType<String>()
        .where((k) => k.startsWith(_prefix))
        .toList();
    for (final key in keys) {
      _storage.removeItem(key);
    }
  });
}
