import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What is kept in secure storage for one server.
@immutable
sealed class StoredCredential {
  const StoredCredential({this.persistent = true});

  /// Web only: `false` keeps the credential for the browser tab session,
  /// `true` ("remember me") keeps it across browser restarts. Mobile always
  /// uses the platform keystore.
  final bool persistent;

  /// Parses stored text. Plain text (no JSON) is a long-lived token saved by
  /// version 0.1.0, so existing sign-ins keep working after an update.
  static StoredCredential? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('{')) return LongLivedToken(raw);
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      final persistent = json['persistent'] != false;
      switch (json['type']) {
        case 'llat':
          final token = json['token'];
          return token is String && token.isNotEmpty
              ? LongLivedToken(token, persistent: persistent)
              : null;
        case 'oauth':
          final access = json['accessToken'];
          final refresh = json['refreshToken'];
          final clientId = json['clientId'];
          final expires = json['expiresAt'];
          if (access is! String ||
              refresh is! String ||
              clientId is! String ||
              expires is! String) {
            return null;
          }
          final expiresAt = DateTime.tryParse(expires);
          if (expiresAt == null) return null;
          return OAuthTokens(
            accessToken: access,
            refreshToken: refresh,
            clientId: clientId,
            expiresAt: expiresAt,
            persistent: persistent,
          );
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String serialize();
}

/// Long-lived access token created in the Home Assistant user profile.
final class LongLivedToken extends StoredCredential {
  const LongLivedToken(this.token, {super.persistent});

  final String token;

  @override
  String serialize() =>
      jsonEncode({'type': 'llat', 'token': token, 'persistent': persistent});
}

/// Tokens from the OAuth2 authorization-code flow
/// (https://developers.home-assistant.io/docs/auth_api/).
final class OAuthTokens extends StoredCredential {
  const OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.clientId,
    required this.expiresAt,
    super.persistent,
  });

  /// Short-lived (Home Assistant: 30 minutes).
  final String accessToken;

  /// Long-lived; exchanged for new access tokens, revoked on sign-out.
  final String refreshToken;

  /// The client id the refresh token is bound to.
  final String clientId;
  final DateTime expiresAt;

  /// Refresh a bit early so a request never starts with a token that
  /// expires on the way.
  bool needsRefresh(
    DateTime now, {
    Duration margin = const Duration(seconds: 60),
  }) => !now.add(margin).isBefore(expiresAt);

  OAuthTokens withAccessToken(String token, DateTime expiresAt) => OAuthTokens(
    accessToken: token,
    refreshToken: refreshToken,
    clientId: clientId,
    expiresAt: expiresAt,
    persistent: persistent,
  );

  @override
  String serialize() => jsonEncode({
    'type': 'oauth',
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'clientId': clientId,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'persistent': persistent,
  });
}
