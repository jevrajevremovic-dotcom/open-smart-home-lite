import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../transport/transport.dart';
import '../transport/transport_error.dart';

/// Translates transport errors into [AppFailure]. Never copies request
/// headers or bodies into the failure.
AppFailure mapDioException(
  DioException e, {
  CertificateInfo? rejectedCertificate,
}) {
  final path = e.requestOptions.path;
  final error = e.error;
  final transportError = classifyTransportError(error);

  if (rejectedCertificate != null ||
      e.type == DioExceptionType.badCertificate ||
      transportError == TransportErrorKind.tls) {
    return AppFailure(
      FailureKind.certificate,
      debugMessage: 'TLS handshake failed for $path',
      certificate: rejectedCertificate,
    );
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return AppFailure(
        FailureKind.timeout,
        debugMessage: '${e.type.name} on $path',
      );
    case DioExceptionType.badResponse:
      return mapStatusCode(e.response?.statusCode, path);
    case DioExceptionType.connectionError:
      return AppFailure(
        FailureKind.network,
        debugMessage: 'connection error on $path: ${error.runtimeType}',
      );
    case DioExceptionType.cancel:
      return AppFailure(
        FailureKind.unknown,
        debugMessage: 'request cancelled: $path',
      );
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      if (transportError == TransportErrorKind.socket) {
        return AppFailure(
          FailureKind.network,
          debugMessage: 'socket error on $path',
        );
      }
      if (error is FormatException) {
        return AppFailure(
          FailureKind.parsing,
          debugMessage: 'invalid response body on $path',
        );
      }
      return AppFailure(
        FailureKind.unknown,
        debugMessage: '${error.runtimeType} on $path',
      );
  }
}

AppFailure mapStatusCode(int? status, String path) {
  final kind = switch (status) {
    401 => FailureKind.authentication,
    403 => FailureKind.authorization,
    400 || 405 || 422 => FailureKind.validation,
    404 => FailureKind.server,
    final int s when s >= 500 => FailureKind.server,
    _ => FailureKind.unknown,
  };
  return AppFailure(
    kind,
    statusCode: status,
    debugMessage: 'HTTP $status on $path',
  );
}
