import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/tls_trust.dart';
import '../websocket/ha_socket.dart';
import 'transport_error.dart';

/// Browsers do not let pages inspect or override certificate validation.
const bool supportsCertificatePinning = false;

/// `null` keeps Dio's default browser adapter (XHR).
HttpClientAdapter? createPlatformHttpAdapter(
  TlsTrust trust, {
  void Function(CertificateInfo certificate)? onRejected,
}) => null;

HaSocketConnector platformSocketConnector(TlsTrust trust) => (uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return ChannelSocket(channel);
};

/// The browser hides the cause of failed requests (CORS, mixed content,
/// TLS and DNS errors all look the same), so nothing can be classified.
TransportErrorKind? classifyTransportError(Object? error) => null;
