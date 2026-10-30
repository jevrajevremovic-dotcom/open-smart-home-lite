import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as hash;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import 'lan_http.dart';

// The ways the phone talks to devices besides JSON over HTTP (LanHttp):
// any HTTP (XML, binary, HTTPS with the device's own certificate), UDP,
// a TCP connection and a WebSocket. Each is an interface, so tests answer
// as the devices would.

/// A device's HTTP answer.
@immutable
class LanResponse {
  const LanResponse(
    this.status,
    this.body, {
    this.headers = const {},
    this.certificate,
  });

  final int status;
  final Uint8List body;

  /// Lower-case names.
  final Map<String, String> headers;

  /// The device's own certificate (SHA-256 of it, hex), when asked with
  /// `insecure`: kept at pairing, then required ([LanRequests.send] `pin`).
  final String? certificate;

  bool get ok => status >= 200 && status < 300;
  String get text => utf8.decode(body, allowMalformed: true);

  /// The body as JSON; `null` when it is not.
  Object? get json {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// HTTP of any kind to a device on the local network. [insecure] accepts
/// the device's self-signed certificate (a hub's or TV's own HTTPS); with
/// [pin], only that certificate (trusted the first time, then required).
abstract interface class LanRequests {
  /// Throws `AppFailure` (network, timeout, authentication for 401/403);
  /// other statuses come back as they are.
  Future<LanResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool insecure = false,
    String? pin,
    LanAuth? auth,
    Duration timeout = const Duration(seconds: 5),
  });
}

/// The SHA-256 of a certificate ([der] bytes), hex.
String certificateFingerprint(List<int> der) =>
    hash.sha256.convert(der).toString();

/// A self-signed certificate check for [host]: accepts it the first time
/// ([pin] `null`), afterwards only the same one. Records what was seen.
class _Pinning {
  _Pinning(this.host, this.pin);

  final String host;
  final String? pin;
  String? seen;
  bool get mismatch => pin != null && seen != null && seen != pin;

  bool check(X509Certificate cert, String host, int _) {
    if (host != this.host) return false;
    seen = certificateFingerprint(cert.der);
    return pin == null || seen == pin;
  }
}

/// [body] as JSON, with its header.
({Map<String, String> headers, List<int> body}) jsonBody(Object? body) => (
  headers: const {'content-type': 'application/json'},
  body: utf8.encode(jsonEncode(body)),
);

class IoLanRequests implements LanRequests {
  @override
  Future<LanResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    bool insecure = false,
    String? pin,
    LanAuth? auth,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final pinning = _Pinning(uri.host, pin);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      // Only for the one device asked: its own certificate.
      ..badCertificateCallback = insecure ? pinning.check : null;
    Future<LanResponse> once(String? authorization) async {
      final request = await client.openUrl(method, uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (authorization != null) {
        request.headers.set(HttpHeaders.authorizationHeader, authorization);
      }
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close();
      final bytes = BytesBuilder(copy: false);
      await response.forEach(bytes.add);
      final names = <String, String>{};
      response.headers.forEach((k, v) => names[k.toLowerCase()] = v.join(','));
      return LanResponse(
        response.statusCode,
        bytes.takeBytes(),
        headers: names,
        certificate: pinning.seen,
      );
    }

    try {
      return await () async {
        var r = await once(
          auth != null && !auth.digest
              ? 'Basic ${base64.encode(utf8.encode('${auth.user}:${auth.password}'))}'
              : null,
        );
        final challenge = r.headers['www-authenticate'];
        if (r.status == 401 &&
            auth != null &&
            auth.digest &&
            challenge != null) {
          final header = digestAuthorization(
            challenge: challenge,
            method: method,
            uri: uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
            auth: auth,
            cnonce: _cnonce(),
          );
          if (header != null) r = await once(header);
        }
        if (r.status == 401 || r.status == 403) {
          throw AppFailure(
            FailureKind.authentication,
            debugMessage: '${uri.host}: ${r.status}',
          );
        }
        return r;
      }().timeout(timeout);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw AppFailure(FailureKind.timeout, debugMessage: uri.host);
    } on Object {
      throw AppFailure(
        // Another certificate than at pairing: someone else may answer.
        pinning.mismatch ? FailureKind.certificate : FailureKind.network,
        debugMessage: uri.host,
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _cnonce() {
    final r = Random.secure();
    return [for (var i = 0; i < 8; i++) r.nextInt(256)]
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// A UDP datagram, and who sent it.
@immutable
class UdpPacket {
  const UdpPacket(this.host, this.data);

  final String host;
  final Uint8List data;

  String get text => utf8.decode(data, allowMalformed: true);
}

abstract interface class LanUdp {
  /// Sends [data] to [host]:[port] (`255.255.255.255` broadcasts) and
  /// collects the answers for up to [wait]: only the first when [first].
  /// Answers come to [listenPort] (0: any free port). [wait] of zero only
  /// sends.
  Future<List<UdpPacket>> ask(
    String host,
    int port,
    List<int> data, {
    Duration wait = const Duration(seconds: 2),
    bool first = true,
    int listenPort = 0,
  });

  /// Datagrams devices broadcast to [port], for [duration].
  Stream<UdpPacket> listen(int port, {required Duration duration});
}

class IoLanUdp implements LanUdp {
  @override
  Future<List<UdpPacket>> ask(
    String host,
    int port,
    List<int> data, {
    Duration wait = const Duration(seconds: 2),
    bool first = true,
    int listenPort = 0,
  }) async {
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
        reuseAddress: true,
      );
    } on SocketException {
      throw AppFailure(FailureKind.network, debugMessage: 'udp $listenPort');
    }
    socket.broadcastEnabled = true;
    final answers = <UdpPacket>[];
    final done = Completer<void>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = socket.receive();
      if (d == null) return;
      answers.add(UdpPacket(d.address.address, d.data));
      if (first && !done.isCompleted) done.complete();
    });
    try {
      final to = InternetAddress(host);
      socket.send(data, to, port);
      if (wait == Duration.zero) return const [];
      // UDP may be lost: asked again halfway.
      final again = Timer(wait ~/ 2, () {
        if (answers.isEmpty) socket.send(data, to, port);
      });
      await done.future.timeout(wait, onTimeout: () {});
      again.cancel();
      return answers;
    } on ArgumentError {
      throw AppFailure(FailureKind.network, debugMessage: 'udp $host');
    } finally {
      await sub.cancel();
      socket.close();
    }
  }

  @override
  Stream<UdpPacket> listen(int port, {required Duration duration}) async* {
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
    } on SocketException {
      return;
    }
    final out = StreamController<UdpPacket>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = socket.receive();
      if (d != null) out.add(UdpPacket(d.address.address, d.data));
    });
    final timer = Timer(duration, () async {
      await sub.cancel();
      socket.close();
      await out.close();
    });
    try {
      yield* out.stream;
    } finally {
      timer.cancel();
      await sub.cancel();
      socket.close();
    }
  }
}

/// An open TCP connection to a device.
abstract interface class LanLink {
  Stream<Uint8List> get data;
  void add(List<int> bytes);
  Future<void> close();
}

abstract interface class LanTcp {
  /// Throws `AppFailure` when the device does not answer.
  Future<LanLink> connect(String host, int port);
}

class IoLanTcp implements LanTcp {
  @override
  Future<LanLink> connect(String host, int port) async {
    try {
      // ignore: close_sinks, closed by the link's close()
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      return _SocketLink(socket);
    } on Object {
      throw AppFailure(FailureKind.network, debugMessage: '$host:$port');
    }
  }
}

class _SocketLink implements LanLink {
  _SocketLink(this._socket) : data = _socket.asBroadcastStream();

  final Socket _socket;

  @override
  final Stream<Uint8List> data;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() async => _socket.destroy();
}

/// An open WebSocket to a device (a TV).
abstract interface class LanWebSocket {
  Stream<String> get messages;

  /// The device's certificate (SHA-256, hex) on `wss`, else `null`.
  String? get certificate;
  void send(String text);
  Future<void> close();
}

abstract interface class LanSockets {
  /// [insecure]: the device's own certificate; with [pin], only that one.
  /// Throws `AppFailure` (certificate when it is another one).
  Future<LanWebSocket> connect(Uri uri, {bool insecure = false, String? pin});
}

class IoLanSockets implements LanSockets {
  @override
  Future<LanWebSocket> connect(
    Uri uri, {
    bool insecure = false,
    String? pin,
  }) async {
    final pinning = _Pinning(uri.host, pin);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = insecure ? pinning.check : null;
    try {
      // ignore: close_sinks, closed by the link's close()
      final socket = await WebSocket.connect(
        uri.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 6));
      return _IoWebSocket(socket, pinning.seen);
    } on Object {
      client.close(force: true);
      throw AppFailure(
        pinning.mismatch ? FailureKind.certificate : FailureKind.network,
        debugMessage: uri.host,
      );
    }
  }
}

class _IoWebSocket implements LanWebSocket {
  _IoWebSocket(this._socket, this.certificate)
    : messages = _socket
          .map((m) => m is String ? m : utf8.decode(m as List<int>))
          .asBroadcastStream();

  final WebSocket _socket;

  @override
  final Stream<String> messages;

  @override
  final String? certificate;

  @override
  void send(String text) => _socket.add(text);

  @override
  Future<void> close() => _socket.close();
}

/// Wakes a device that is off but listening (a TV) with the magic packet
/// to its [mac] (`aabbccddeeff`).
Future<void> wakeOnLan(LanUdp udp, String mac) async {
  final bytes = [
    for (var i = 0; i < 12; i += 2)
      int.parse(mac.substring(i, i + 2), radix: 16),
  ];
  final packet = [
    for (var i = 0; i < 6; i++) 0xFF,
    for (var i = 0; i < 16; i++) ...bytes,
  ];
  await udp.ask('255.255.255.255', 9, packet, wait: Duration.zero);
}

final lanRequestsProvider = Provider<LanRequests>((ref) => IoLanRequests());
final lanUdpProvider = Provider<LanUdp>((ref) => IoLanUdp());
final lanTcpProvider = Provider<LanTcp>((ref) => IoLanTcp());
final lanSocketsProvider = Provider<LanSockets>((ref) => IoLanSockets());
