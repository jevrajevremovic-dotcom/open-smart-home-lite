import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../core/errors/app_failure.dart';
import '../../authentication/application/session_controller.dart';
import 'settings_backup.dart';

/// Where a saved copy lives in Home Assistant.
enum BackupScope {
  /// Shared by every user of the home (written by an administrator).
  home,

  /// This Home Assistant user's own.
  user,
}

/// One saved copy of the app's settings.
@immutable
class HaBackup {
  const HaBackup({
    required this.name,
    required this.scope,
    required this.savedAt,
    required this.settings,
    this.appVersion,
  });

  final String name;
  final BackupScope scope;
  final DateTime? savedAt;
  final String? appVersion;
  final Map<Object?, Object?> settings;
}

/// The app's settings kept in Home Assistant's own frontend storage
/// (`frontend/set_system_data` for the whole home, `frontend/set_user_data`
/// per user — homeassistant/components/frontend/storage.py), under one key,
/// by device name. Tokens, PINs and photos are never in it.
class HaBackupService {
  HaBackupService(this._send);

  static const key = 'open_smart_home_settings';

  final Future<Object?> Function(Map<String, Object?>) _send;

  Future<Map<String, Object?>> _read(BackupScope scope) async {
    final result = await _send({
      'type': scope == BackupScope.home
          ? 'frontend/get_system_data'
          : 'frontend/get_user_data',
      'key': key,
    });
    final value = result is Map ? result['value'] : null;
    return value is Map ? value.cast<String, Object?>() : {};
  }

  Future<void> _write(BackupScope scope, Map<String, Object?> value) => _send({
    'type': scope == BackupScope.home
        ? 'frontend/set_system_data'
        : 'frontend/set_user_data',
    'key': key,
    'value': value,
  });

  /// Every saved copy, the home's first.
  Future<List<HaBackup>> list() async {
    final out = <HaBackup>[];
    for (final scope in BackupScope.values) {
      final Map<String, Object?> entries;
      try {
        entries = await _read(scope);
      } on AppFailure {
        continue;
      }
      for (final e in entries.entries) {
        final v = e.value;
        if (v is! Map || v['settings'] is! Map) continue;
        out.add(
          HaBackup(
            name: e.key,
            scope: scope,
            savedAt: DateTime.tryParse('${v['savedAt']}'),
            appVersion: v['appVersion'] as String?,
            settings: v['settings']! as Map,
          ),
        );
      }
    }
    return out;
  }

  /// Saves [settings] as [name]: for the whole home when allowed (an
  /// administrator), else for this user. Returns where it went.
  Future<BackupScope> save(
    String name,
    Map<String, Object?> settings, {
    DateTime? now,
  }) async {
    final entry = {
      'savedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
      'settings': settings,
    };
    for (final scope in BackupScope.values) {
      try {
        final entries = await _read(scope);
        await _write(scope, {...entries, name: entry});
        return scope;
      } on AppFailure catch (e) {
        // Not an administrator: the user's own store instead.
        if (scope == BackupScope.home && e.kind == FailureKind.authorization) {
          continue;
        }
        rethrow;
      }
    }
    throw const AppFailure(FailureKind.server);
  }

  Future<void> delete(HaBackup backup) async {
    final entries = await _read(backup.scope);
    entries.remove(backup.name);
    await _write(backup.scope, entries);
  }
}

final haBackupServiceProvider = Provider<HaBackupService?>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager == null ? null : HaBackupService(manager.sendCommand);
});

/// Restores [backup] into this device (same rules as a pasted backup).
Future<bool> restoreHaBackup(WidgetRef ref, HaBackup backup) =>
    SettingsBackup.importMap(ref, backup.settings);
