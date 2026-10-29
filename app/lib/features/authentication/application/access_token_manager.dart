import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/credential_store.dart';
import '../../../integrations/home_assistant/auth/ha_auth_client.dart';
import '../domain/stored_credential.dart';

/// Hands out a valid access token for one server.
///
/// * Long-lived tokens are returned as stored.
/// * OAuth2 access tokens are refreshed shortly before they expire; parallel
///   callers share a single refresh request.
/// * A rejected refresh token surfaces as `FailureKind.authentication`
///   (the user has to sign in again); network problems stay transient.
class AccessTokenManager {
  AccessTokenManager({
    required this.serverId,
    required this._store,
    required this._authClient,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String serverId;
  final CredentialStore _store;
  final HaAuthClient Function() _authClient;
  final DateTime Function() _now;
  static final _log = AppLogger('AccessToken');

  StoredCredential? _credential;
  bool _loaded = false;
  Future<String?>? _refreshing;

  Future<StoredCredential?> credential() async {
    if (!_loaded) {
      _credential = StoredCredential.parse(
        await _store.readCredential(serverId),
      );
      _loaded = true;
    }
    return _credential;
  }

  Future<String?> accessToken() async => switch (await credential()) {
    null => null,
    LongLivedToken(:final token) => token,
    final OAuthTokens t when !t.needsRefresh(_now()) => t.accessToken,
    final OAuthTokens t => _refreshing ??= _refresh(
      t,
    ).whenComplete(() => _refreshing = null),
  };

  Future<String?> _refresh(OAuthTokens tokens) async {
    _log.debug('Refreshing access token');
    final response = await _authClient().refresh(
      refreshToken: tokens.refreshToken,
      clientId: tokens.clientId,
    );
    final next = tokens.withAccessToken(
      response.accessToken,
      _now().add(response.expiresIn),
    );
    _credential = next;
    await _store.writeCredential(
      serverId,
      next.serialize(),
      persistent: next.persistent,
    );
    return next.accessToken;
  }

  /// Revokes an OAuth2 refresh token on the server (best effort, bounded so
  /// signing out offline is not blocked).
  Future<void> revoke() async {
    final c = await credential();
    if (c is! OAuthTokens) return;
    try {
      await _authClient()
          .revoke(c.refreshToken)
          .timeout(const Duration(seconds: 5));
    } on Object catch (e) {
      _log.warning('Could not revoke refresh token', e.runtimeType);
    }
  }
}
