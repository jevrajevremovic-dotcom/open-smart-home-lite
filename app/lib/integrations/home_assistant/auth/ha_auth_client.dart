import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/server_address.dart';
import '../../../core/network/tls_trust.dart';
import '../api/dio_error_mapper.dart';
import '../transport/transport.dart';

/// Response of `POST /auth/token`.
@immutable
class OAuthTokenResponse {
  const OAuthTokenResponse({
    required this.accessToken,
    required this.expiresIn,
    this.refreshToken,
  });

  factory OAuthTokenResponse.fromJson(Object? json) {
    if (json is! Map) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'token response is not an object',
      );
    }
    final access = json['access_token'];
    final expires = json['expires_in'];
    final refresh = json['refresh_token'];
    if (access is! String || access.isEmpty || expires is! num) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'token response incomplete',
      );
    }
    return OAuthTokenResponse(
      accessToken: access,
      expiresIn: Duration(seconds: expires.toInt()),
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
    );
  }

  final String accessToken;
  final Duration expiresIn;

  /// Only returned for the `authorization_code` grant.
  final String? refreshToken;
}

/// Home Assistant Authentication API
/// (https://developers.home-assistant.io/docs/auth_api/).
abstract interface class HaAuthClient {
  /// URL of Home Assistant's login page; after login HA redirects to
  /// [redirectUri] with `code` and `state` query parameters.
  Uri authorizeUrl({
    required String clientId,
    required Uri redirectUri,
    required String state,
  });

  /// `grant_type=authorization_code`.
  Future<OAuthTokenResponse> exchangeCode({
    required String code,
    required String clientId,
  });

  /// `grant_type=refresh_token`. Throws [FailureKind.authentication] when
  /// the refresh token was revoked or is unknown.
  Future<OAuthTokenResponse> refresh({
    required String refreshToken,
    required String clientId,
  });

  /// Revokes a refresh token (and its access tokens). Best effort.
  Future<void> revoke(String refreshToken);
}

class DioHaAuthClient implements HaAuthClient {
  DioHaAuthClient({
    required this.address,
    TlsTrust trust = TlsTrust.system,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = address.baseUri.toString()
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..followRedirects = false
      ..contentType = Headers.formUrlEncodedContentType
      ..validateStatus = (status) =>
          status != null && status >= 200 && status < 300;
    final adapter = dio == null ? createPlatformHttpAdapter(trust) : null;
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final ServerAddress address;
  final Dio _dio;
  static final _log = AppLogger('HaAuth');

  @override
  Uri authorizeUrl({
    required String clientId,
    required Uri redirectUri,
    required String state,
  }) => address
      .restUri('/auth/authorize')
      .replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri.toString(),
          'state': state,
        },
      );

  @override
  Future<OAuthTokenResponse> exchangeCode({
    required String code,
    required String clientId,
  }) => _token({
    'grant_type': 'authorization_code',
    'code': code,
    'client_id': clientId,
  });

  @override
  Future<OAuthTokenResponse> refresh({
    required String refreshToken,
    required String clientId,
  }) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': clientId,
  });

  @override
  Future<void> revoke(String refreshToken) async {
    try {
      await _dio.post<Object?>('/auth/revoke', data: {'token': refreshToken});
    } on DioException catch (e) {
      // Revocation is best effort: sign-out continues locally either way.
      _log.warning('Token revocation failed', mapDioException(e));
    }
  }

  Future<OAuthTokenResponse> _token(Map<String, String> form) async {
    try {
      final response = await _dio.post<Object?>('/auth/token', data: form);
      return OAuthTokenResponse.fromJson(response.data);
    } on DioException catch (e) {
      final failure = mapDioException(e);
      // The token endpoint answers 400 {"error": "invalid_grant"} for an
      // expired code or a revoked refresh token: the user must sign in again.
      if (failure.statusCode == 400 || failure.statusCode == 403) {
        throw AppFailure(
          FailureKind.authentication,
          statusCode: failure.statusCode,
          debugMessage: 'token endpoint rejected ${form['grant_type']}',
        );
      }
      throw failure;
    }
  }
}
