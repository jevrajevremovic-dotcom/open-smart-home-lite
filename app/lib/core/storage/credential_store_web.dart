import 'package:web/web.dart' as web;

import '../errors/app_failure.dart';
import '../logging/app_logger.dart';
import 'credential_store.dart';

CredentialStore createPlatformCredentialStore() => BrowserCredentialStore();

/// Browser storage for credentials.
///
/// Browsers have no hardware-backed secret store comparable to Keychain or
/// Keystore, and Web Crypto is unavailable on plain-HTTP origins (the usual
/// `http://homeassistant.local:8123`). So:
/// * default: the tab's `sessionStorage` – gone when the tab closes;
/// * "remember me": `localStorage` – survives restarts, like Home
///   Assistant's own frontend does. Only offered with OAuth2, where the
///   stored refresh token can be revoked from the HA profile at any time.
class BrowserCredentialStore implements CredentialStore {
  static const _prefix = 'ha_access_token::';
  static final _log = AppLogger('CredentialStore');

  web.Storage get _session => web.window.sessionStorage;
  web.Storage get _local => web.window.localStorage;

  @override
  Future<String?> readCredential(String serverId) async => _guard(
    'read',
    () =>
        _session.getItem('$_prefix$serverId') ??
        _local.getItem('$_prefix$serverId'),
  );

  @override
  Future<void> writeCredential(
    String serverId,
    String value, {
    bool persistent = false,
  }) async => _guard('write', () {
    // Exactly one copy, in the store the user chose.
    (persistent ? _session : _local).removeItem('$_prefix$serverId');
    (persistent ? _local : _session).setItem('$_prefix$serverId', value);
  });

  @override
  Future<void> deleteCredential(String serverId) async => _guard('delete', () {
    _session.removeItem('$_prefix$serverId');
    _local.removeItem('$_prefix$serverId');
  });

  @override
  Future<void> deleteAll() async => _guard('deleteAll', () {
    for (final storage in [_session, _local]) {
      final keys = [for (var i = 0; i < storage.length; i++) storage.key(i)]
          .whereType<String>()
          .where((k) => k.startsWith(_prefix))
          .toList();
      for (final key in keys) {
        storage.removeItem(key);
      }
    }
  });

  T _guard<T>(String op, T Function() action) {
    try {
      return action();
    } on Object catch (e) {
      _log.error('Browser storage $op failed', e.runtimeType);
      throw AppFailure(
        FailureKind.storage,
        debugMessage: 'browser storage $op failed',
      );
    }
  }
}
