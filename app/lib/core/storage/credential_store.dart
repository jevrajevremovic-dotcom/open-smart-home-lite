import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'credential_store_io.dart'
    if (dart.library.js_interop) 'credential_store_web.dart';

/// Secret storage for server credentials (serialized `StoredCredential`).
/// Values never leave this class except to the token manager.
///
/// * Android / iOS: Keychain / Keystore (`credential_store_io.dart`).
/// * Web: the tab's `sessionStorage`, or `localStorage` when the user chose
///   "remember me" (`credential_store_web.dart`).
abstract interface class CredentialStore {
  Future<String?> readCredential(String serverId);

  /// [persistent] only matters on the web (see above).
  Future<void> writeCredential(
    String serverId,
    String value, {
    bool persistent = false,
  });
  Future<void> deleteCredential(String serverId);
  Future<void> deleteAll();
}

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => createPlatformCredentialStore(),
);
