import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../../core/storage/credential_store.dart';
import '../../devices/data/cache/snapshot_cache.dart';
import '../domain/stored_credential.dart';
import 'server_profile.dart';

/// Persists which server the app is connected to and its access token.
class SessionRepository {
  SessionRepository(this._preferences, this._credentials, this._cache);

  final AppPreferences _preferences;
  final CredentialStore _credentials;
  final SnapshotCache _cache;

  /// The stored profile, but only if a valid credential for it also exists.
  Future<ServerProfile?> loadProfile() async {
    final profile = ServerProfile.tryFromJson(_preferences.serverProfileJson);
    if (profile == null) return null;
    final credential = StoredCredential.parse(
      await _credentials.readCredential(profile.id),
    );
    return credential == null ? null : profile;
  }

  Future<void> save(ServerProfile profile, StoredCredential credential) async {
    // Credential first: a profile without one is treated as signed-out.
    await _credentials.writeCredential(
      profile.id,
      credential.serialize(),
      persistent: credential.persistent,
    );
    // Keep the current home in the list (it may predate the list).
    final previous = ServerProfile.tryFromJson(_preferences.serverProfileJson);
    if (previous != null && previous.id != profile.id) {
      await _remember(previous);
    }
    await _preferences.setServerProfileJson(profile.toJson());
    await _remember(profile);
  }

  // --- Several homes -------------------------------------------------------

  static const _savedKey = 'connection.savedProfiles';
  static const _namesKey = 'connection.homeNames';

  List<ServerProfile> _saved() => [
    if (_preferences.readJson(_savedKey)?['profiles']
        case final List<Object?> l)
      for (final p in l)
        if (p is Map<String, Object?>) ?ServerProfile.tryFromJson(p),
  ];

  Future<void> _writeSaved(List<ServerProfile> profiles) =>
      _preferences.writeJson(_savedKey, {
        'profiles': [for (final p in profiles) p.toJson()],
      });

  Future<void> _remember(ServerProfile profile) async {
    final list = _saved()..removeWhere((p) => p.id == profile.id);
    await _writeSaved([...list, profile]);
  }

  /// Homes the user signed in to that still have a credential (the active
  /// one included, also when it predates this list).
  Future<List<ServerProfile>> savedProfiles() async {
    final active = ServerProfile.tryFromJson(_preferences.serverProfileJson);
    final all = [
      ..._saved(),
      if (active != null && !_saved().any((p) => p.id == active.id)) active,
    ];
    return [
      for (final p in all)
        if (StoredCredential.parse(await _credentials.readCredential(p.id)) !=
            null)
          p,
    ];
  }

  /// Stores changed non-secret details (e.g. a remote address) of a home.
  Future<void> update(ServerProfile profile) async {
    final active = ServerProfile.tryFromJson(_preferences.serverProfileJson);
    if (active?.id == profile.id) {
      await _preferences.setServerProfileJson(profile.toJson());
    }
    if (_saved().any((p) => p.id == profile.id) || active?.id == profile.id) {
      await _remember(profile);
    }
  }

  /// Makes a saved home the active one.
  Future<void> activate(ServerProfile profile) =>
      _preferences.setServerProfileJson(profile.toJson());

  /// Display names (Home Assistant's `location_name`) by profile id.
  Map<String, String> homeNames() => {
    if (_preferences.readJson(_namesKey) case final Map<String, Object?> m)
      for (final e in m.entries)
        if (e.value is String) e.key: e.value! as String,
  };

  Future<void> setHomeName(String profileId, String name) async {
    final names = homeNames();
    if (names[profileId] == name) return;
    await _preferences.writeJson(_namesKey, {...names, profileId: name});
  }

  /// Removes the token, cache and saved entry of [profile]; keeps theme
  /// and language. Returns another saved home to switch to, if any.
  Future<ServerProfile?> signOut(ServerProfile? profile) async {
    if (profile != null) {
      await _credentials.deleteCredential(profile.id);
      // The mobile_app webhook id of this home is a secret as well.
      await _credentials.deleteCredential('mobile_app::${profile.id}');
      await _cache.clear(profile.id);
      await _writeSaved(_saved()..removeWhere((p) => p.id == profile.id));
      final names = homeNames()..remove(profile.id);
      await _preferences.writeJson(_namesKey, names);
    }
    final remaining = await savedProfiles();
    final next = remaining.where((p) => p.id != profile?.id).firstOrNull;
    await _preferences.setServerProfileJson(next?.toJson());
    return next;
  }

  /// Removes every locally stored value, secrets included.
  Future<void> deleteAllLocalData() async {
    await _credentials.deleteAll();
    await _cache.clearAll();
    await _preferences.clear();
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(
    ref.watch(appPreferencesProvider),
    ref.watch(credentialStoreProvider),
    ref.watch(snapshotCacheProvider),
  ),
);
