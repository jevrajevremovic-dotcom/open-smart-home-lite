import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/core/network/server_address.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/api/dio_error_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/api/dio_home_assistant_api.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/api/home_assistant_api.dart';

/// Serves canned responses and records requests, without network access.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
    final text = body is String ? body : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final address = (ServerAddress.parse(
  'http://192.168.1.10:8123',
) as ValidServerAddress).address;

(DioHomeAssistantApi, FakeAdapter) build(
  (int, Object?) Function(RequestOptions) handler, {
  String? token = 'good-token',
}) {
  final adapter = FakeAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    DioHomeAssistantApi(
      address: address,
      readToken: () async => token,
      dio: dio,
    ),
    adapter,
  );
}

void main() {
  group('probe', () {
    test('401 on /api/ means Home Assistant requiring auth', () async {
      final (api, adapter) = build((_) => (401, '401: Unauthorized'));
      expect(await api.probe(), ServerProbeResult.reachableRequiresAuth);
      expect(adapter.requests.single.path, '/api/');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('other responses are unexpected', () async {
      final (api, _) = build((_) => (200, '<html></html>'));
      expect(await api.probe(), ServerProbeResult.unexpectedResponse);
      final (api404, _) = build((_) => (404, 'not found'));
      expect(await api404.probe(), ServerProbeResult.unexpectedResponse);
    });
  });

  group('authenticated requests', () {
    test('send bearer token and accept documented /api/ response', () async {
      final (api, adapter) = build((_) => (200, {'message': 'API running.'}));
      await api.verifyAccessToken();
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer good-token',
      );
    });

    test('wrong token maps to authentication failure', () async {
      final (api, _) = build((_) => (401, '401: Unauthorized'));
      await expectLater(
        api.verifyAccessToken(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.authentication,
          ),
        ),
      );
    });

    test('missing token fails without a request', () async {
      final (api, adapter) = build((_) => (200, {}), token: null);
      await expectLater(api.fetchStates(), throwsA(isA<AppFailure>()));
      expect(adapter.requests, isEmpty);
    });

    test('config without version is rejected as non-HA', () async {
      final (api, _) = build((_) => (200, {'location_name': 'x'}));
      await expectLater(
        api.fetchConfig(),
        throwsA(
          isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.parsing),
        ),
      );
    });

    test('states parsing skips malformed entries', () async {
      final (api, _) = build(
        (_) => (
          200,
          [
            {
              'entity_id': 'light.kitchen',
              'state': 'on',
              'attributes': {'friendly_name': 'Kitchen'},
            },
            {'entity_id': 'NOT VALID', 'state': 'on'},
            'garbage',
            {
              'entity_id': 'sensor.t',
              'state': '21.5',
              'attributes': 'not-a-map',
            },
          ],
        ),
      );
      final states = await api.fetchStates();
      expect(states.map((s) => s.entityId), ['light.kitchen', 'sensor.t']);
      expect(states.first.friendlyName, 'Kitchen');
      expect(states.last.attributes, isEmpty);
    });

    test('callService posts JSON to the documented path', () async {
      final (api, adapter) = build((_) => (200, <Object?>[]));
      await api.callService(
        'light',
        'turn_on',
        data: {'entity_id': 'light.kitchen', 'brightness_pct': 40},
      );
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/services/light/turn_on');
      expect(req.data, {'entity_id': 'light.kitchen', 'brightness_pct': 40});
    });

    test('callService refuses path-injection in names', () async {
      final (api, adapter) = build((_) => (200, <Object?>[]));
      await expectLater(
        api.callService('light/../../x', 'turn_on'),
        throwsA(isA<AppFailure>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('mapDioException', () {
    DioException ex(DioExceptionType type, {Object? error, int? status}) {
      final options = RequestOptions(path: '/api/');
      return DioException(
        requestOptions: options,
        type: type,
        error: error,
        response: status == null
            ? null
            : Response<void>(requestOptions: options, statusCode: status),
      );
    }

    test('maps transport and status errors', () {
      expect(
        mapDioException(ex(DioExceptionType.connectionTimeout)).kind,
        FailureKind.timeout,
      );
      expect(
        mapDioException(
          ex(
            DioExceptionType.connectionError,
            error: const SocketException('x'),
          ),
        ).kind,
        FailureKind.network,
      );
      expect(
        mapDioException(
          ex(DioExceptionType.unknown, error: const HandshakeException('x')),
        ).kind,
        FailureKind.certificate,
      );
      expect(
        mapDioException(ex(DioExceptionType.badResponse, status: 403)).kind,
        FailureKind.authorization,
      );
      expect(
        mapDioException(ex(DioExceptionType.badResponse, status: 502)).kind,
        FailureKind.server,
      );
    });

    test('carries a rejected certificate for the trust dialog', () {
      final cert = CertificateInfo(
        sha256Fingerprint: 'AA:BB',
        subject: 'CN=ha',
        issuer: 'CN=ha',
        validFrom: DateTime(2026),
        validUntil: DateTime(2027),
      );
      final f = mapDioException(
        ex(DioExceptionType.unknown),
        rejectedCertificate: cert,
      );
      expect(f.kind, FailureKind.certificate);
      expect(f.certificate, same(cert));
    });
  });
}
