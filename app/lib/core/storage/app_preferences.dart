import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

/// Non-secret settings only. Tokens live in `CredentialStore`.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;
  static final _log = AppLogger('AppPreferences');

  static const _themeModeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';
  static const _serverProfileKey = 'connection.activeServerProfile';

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_themeModeKey),
    orElse: () => ThemeMode.system,
  );

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  /// `null` means "follow the system language".
  String? get localeTag => _prefs.getString(_localeKey);

  Future<void> setLocaleTag(String? tag) => tag == null
      ? _prefs.remove(_localeKey)
      : _prefs.setString(_localeKey, tag);

  Map<String, Object?>? get serverProfileJson {
    final raw = _prefs.getString(_serverProfileKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException catch (e) {
      _log.warning('Stored server profile is corrupt, ignoring', e);
      return null;
    }
  }

  Future<void> setServerProfileJson(Map<String, Object?>? json) => json == null
      ? _prefs.remove(_serverProfileKey)
      : _prefs.setString(_serverProfileKey, jsonEncode(json));

  Map<String, Object?>? get kioskSettingsJson => _readJson('kiosk.settings');

  Future<void> setKioskSettingsJson(Map<String, Object?> json) =>
      _prefs.setString('kiosk.settings', jsonEncode(json));

  /// Small JSON documents (e.g. per-server energy tariff).
  Map<String, Object?>? readJson(String key) => _readJson(key);

  Future<void> writeJson(String key, Map<String, Object?>? json) => json == null
      ? _prefs.remove(key)
      : _prefs.setString(key, jsonEncode(json));

  Map<String, Object?>? _readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException catch (e) {
      _log.warning('Stored $key is corrupt, ignoring', e);
      return null;
    }
  }

  /// Ordered favorite device ids for one server.
  List<String> favorites(String serverId) =>
      _prefs.getStringList('favorites::$serverId') ?? const [];

  Future<void> setFavorites(String serverId, List<String> ids) =>
      _prefs.setStringList('favorites::$serverId', ids);

  Future<void> clear() => _prefs.clear();
}

/// Overridden in `bootstrap()` with a loaded [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);
