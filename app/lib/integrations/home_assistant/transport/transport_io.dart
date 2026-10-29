import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/tls_trust.dart';
import '../websocket/ha_socket.dart';
import 'transport_error.dart';

const bool supportsCertificatePinning = true;

/// Colon-separated upper-case SHA-256 of the DER encoding.
String certificateSha256(X509Certificate certificate) =>
    formatFingerprint(sha256.convert(certificate.der).bytes);

CertificateInfo describeCertificate(X509Certificate certificate) =>
    CertificateInfo(
      sha256Fingerprint: certificateSha256(certificate),
      subject: certificate.subject,
      issuer: certificate.issuer,
      validFrom: certificate.startValidity,
      validUntil: certificate.endValidity,
    );

/// Builds an [HttpClient] applying [trust]. [onRejected] receives the
/// certificate the platform refused so the UI can offer to pin it.
///
/// `badCertificateCallback` is only invoked for certificates that already
/// failed normal platform validation; valid certificates are unaffected.
HttpClient createHttpClient(
  TlsTrust trust, {
  void Function(CertificateInfo certificate)? onRejected,
  Duration? connectionTimeout,
}) {
  final client = HttpClient()..connectionTimeout = connectionTimeout;
  client.badCertificateCallback = (certificate, host, port) {
    final pinned = trust.pinnedSha256;
    if (pinned != null && certificateSha256(certificate) == pinned) return true;
    onRejected?.call(describeCertificate(certificate));
    return false;
  };
  return client;
}

HttpClientAdapter? createPlatformHttpAdapter(
  TlsTrust trust, {
  void Function(CertificateInfo certificate)? onRejected,
}) => IOHttpClientAdapter(
  createHttpClient: () => createHttpClient(
    trust,
    connectionTimeout: AppConfig.connectTimeout,
    onRejected: onRejected,
  ),
);

/// `dart:io` WebSocket honouring the same [TlsTrust] as the REST client.
HaSocketConnector platformSocketConnector(TlsTrust trust) => (uri) async {
  final channel = IOWebSocketChannel.connect(
    uri,
    connectTimeout: AppConfig.connectTimeout,
    customClient: createHttpClient(
      trust,
      connectionTimeout: AppConfig.connectTimeout,
    ),
  );
  await channel.ready;
  return ChannelSocket(channel);
};

TransportErrorKind? classifyTransportError(Object? error) => switch (error) {
  HandshakeException() || TlsException() => TransportErrorKind.tls,
  SocketException() || WebSocketException() => TransportErrorKind.socket,
  WebSocketChannelException(:final inner) => classifyTransportError(inner),
  _ => null,
};
