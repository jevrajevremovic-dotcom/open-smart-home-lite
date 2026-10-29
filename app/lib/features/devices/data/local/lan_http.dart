import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';

/// JSON over plain HTTP to a device on the local network.
abstract interface class LanHttp {
  Future<Object?> get(
    String host,
    String path, {
    Map<String, Object?> query = const {},
  });

  Future<Object?> post(String host, String path, Object? body);
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
  }) => _run(() => _dio.getUri<Object?>(_uri(host, path, query)));

  @override
  Future<Object?> post(String host, String path, Object? body) =>
      _run(() => _dio.postUri<Object?>(_uri(host, path, const {}), data: body));

  Future<Object?> _run(Future<Response<Object?>> Function() request) async {
    try {
      return (await request()).data;
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

final lanHttpProvider = Provider<LanHttp>((ref) => DioLanHttp());
