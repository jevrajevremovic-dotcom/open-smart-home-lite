import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_failure.dart';
import '../logging/app_logger.dart';
import 'credential_store.dart';

CredentialStore createPlatformCredentialStore() => SecureCredentialStore();

/// Keychain (iOS) / Keystore-backed encrypted storage (Android).
class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Kiosk tablets reboot unattended, so the token must be readable
            // after first unlock; `this_device` keeps it out of backups.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static final _log = AppLogger('CredentialStore');

  static String _key(String serverId) => 'ha_access_token::$serverId';

  @override
  Future<String?> readCredential(String serverId) =>
      _guard('read', () => _storage.read(key: _key(serverId)));

  @override
  Future<void> writeCredential(
    String serverId,
    String value, {
    bool persistent = false,
  }) =>
      _guard('write', () => _storage.write(key: _key(serverId), value: value));

  @override
  Future<void> deleteCredential(String serverId) =>
      _guard('delete', () => _storage.delete(key: _key(serverId)));

  @override
  Future<void> deleteAll() => _guard('deleteAll', _storage.deleteAll);

  Future<T> _guard<T>(String op, Future<T> Function() action) async {
    try {
      return await action();
    } on Exception catch (e) {
      // The exception text from the platform never includes the value.
      _log.error('Secure storage $op failed', e);
      throw AppFailure(
        FailureKind.storage,
        debugMessage: 'secure storage $op failed',
      );
    }
  }
}
