import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';

/// A device's password: HTTP Basic (sent with every request) or Digest
/// (answered to the device's challenge, SHA-256 or MD5).
@immutable
class LanAuth {
  const LanAuth.basic(this.user, this.password) : digest = false;
  const LanAuth.digest(this.user, this.password) : digest = true;

  final String user;
  final String password;
  final bool digest;

  @override
  String toString() => 'LanAuth($user, ${digest ? 'digest' : 'basic'})';
}

/// JSON over plain HTTP to a device on the local network.
abstract interface class LanHttp {
  Future<Object?> get(
    String host,
    String path, {
    Map<String, Object?> query = const {},
    LanAuth? auth,
  });

  Future<Object?> post(String host, String path, Object? body, {LanAuth? auth});

  Future<Object?> put(String host, String path, Object? body);
}

/// The `Authorization` header answering a Digest [challenge]
/// (`WWW-Authenticate: Digest realm=…, nonce=…, qop=auth, algorithm=…`),
/// RFC 7616. `null` when the challenge is not one this understands.
String? digestAuthorization({
  required String challenge,
  required String method,
  required String uri,
  required LanAuth auth,
  required String cnonce,
  int nc = 1,
}) {
  if (!challenge.trimLeft().toLowerCase().startsWith('digest')) return null;
  final params = {
    for (final m in RegExp(
      r'(\w+)=(?:"([^"]*)"|([^,\s]*))',
    ).allMatches(challenge.substring(challenge.indexOf(' ') + 1)))
      m.group(1)!.toLowerCase(): m.group(2) ?? m.group(3)!,
  };
  final realm = params['realm'];
  final nonce = params['nonce'];
  if (realm == null || nonce == null) return null;
  final algorithm = params['algorithm'] ?? 'MD5';
  final Hash hash = switch (algorithm.toUpperCase()) {
    'SHA-256' => sha256,
    'MD5' => md5,
    _ => throw const AppFailure(
      FailureKind.authentication,
      debugMessage: 'unsupported digest algorithm',
    ),
  };
  String h(String v) => hash.convert(utf8.encode(v)).toString();
  final ha1 = h('${auth.user}:$realm:${auth.password}');
  final ha2 = h('$method:$uri');
  final count = nc.toRadixString(16).padLeft(8, '0');
  final qop = (params['qop'] ?? '').split(',').map((q) => q.trim());
  final withQop = qop.contains('auth');
  final response = withQop
      ? h('$ha1:$nonce:$count:$cnonce:auth:$ha2')
      : h('$ha1:$nonce:$ha2');
  return [
    'Digest username="${auth.user}"',
    'realm="$realm"',
    'nonce="$nonce"',
    'uri="$uri"',
    'algorithm=$algorithm',
    'response="$response"',
    if (withQop) ...['qop=auth', 'nc=$count', 'cnonce="$cnonce"'],
    if (params['opaque'] case final opaque?) 'opaque="$opaque"',
  ].join(', ');
}

class DioLanHttp implements LanHttp {
  DioLanHttp()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 3),
          responseType: ResponseType.json,
          followRedirects: false,
        ),
      );

  final Dio _dio;

  Uri _uri(String host, String path, Map<String, Object?> query) => Uri(
    scheme: 'http',
    host: host,
    path: path,
    queryParameters: query.isEmpty
        ? null
        : {for (final e in query.entries) e.key: '${e.value}'},
  );

  @override
  Future<Object?> get(
    String host,
    String path, {
    Map<String, Object?> query = const {},
    LanAuth? auth,
  }) => _run('GET', _uri(host, path, query), null, auth);

  @override
  Future<Object?> post(
    String host,
    String path,
    Object? body, {
    LanAuth? auth,
  }) => _run('POST', _uri(host, path, const {}), body, auth);

  @override
  Future<Object?> put(String host, String path, Object? body) =>
      _run('PUT', _uri(host, path, const {}), body, null);

  Future<Object?> _run(
    String method,
    Uri uri,
    Object? body,
    LanAuth? auth,
  ) async {
    Future<Response<Object?>> send(String? authorization) =>
        _dio.requestUri<Object?>(
          uri,
          data: body,
          options: Options(
            method: method,
            headers: {'Authorization': ?authorization},
          ),
        );
    try {
      try {
        return (await send(
          auth != null && !auth.digest
              ? 'Basic ${base64.encode(utf8.encode('${auth.user}:${auth.password}'))}'
              : null,
        )).data;
      } on DioException catch (e) {
        final challenge = e.response?.headers.value('www-authenticate');
        if (auth == null ||
            !auth.digest ||
            e.response?.statusCode != 401 ||
            challenge == null) {
          rethrow;
        }
        final header = digestAuthorization(
          challenge: challenge,
          method: method,
          uri: uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
          auth: auth,
          cnonce: _cnonce(),
        );
        if (header == null) rethrow;
        return (await send(header)).data;
      }
    } on DioException catch (e) {
      throw AppFailure(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => FailureKind.timeout,
        DioExceptionType.badResponse when e.response?.statusCode == 401 =>
          FailureKind.authentication,
        DioExceptionType.badResponse => FailureKind.server,
        _ => FailureKind.network,
      }, debugMessage: '${e.requestOptions.uri.path}: ${e.type.name}');
    }
  }
}

String _cnonce() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final lanHttpProvider = Provider<LanHttp>((ref) => DioLanHttp());
