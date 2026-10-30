import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;

import '../../../core/errors/app_failure.dart';
import '../../../core/security/backup_crypto.dart';

/// Sends a backup to another phone or wall panel on the same Wi-Fi: this
/// device serves it once, encrypted with a six-digit code, for a few
/// minutes; the other one types the address and the code.
///
/// Only to someone who shows they know the code ([transferProof]): no one
/// else on the network can take the backup to guess the code at leisure,
/// and after [maxTries] wrong codes the transfer ends.
class LanTransferServer {
  LanTransferServer._(this._server, this.address, this.code);

  final HttpServer _server;

  /// `192.168.1.23:48721`.
  final String address;
  final String code;
  final _done = Completer<bool>();
  int _wrong = 0;

  static const maxTries = 3;

  /// `true` once the other device took it; `false` when it ran out or was
  /// ended ([lockedOut]).
  Future<bool> get done => _done.future;

  /// Ended after [maxTries] wrong codes.
  bool get lockedOut => _wrong >= maxTries;

  static Future<LanTransferServer> start(
    String backup, {
    Duration lifetime = const Duration(minutes: 5),
    String? host,
  }) async {
    final ip = host ?? await localAddress();
    if (ip == null) {
      throw const AppFailure(FailureKind.network, debugMessage: 'no Wi-Fi');
    }
    final code = [for (var i = 0; i < 6; i++) Random.secure().nextInt(10)]
        .join();
    // A short code: fewer rounds, the server lives only minutes and is
    // read once.
    final sealed = jsonEncode(
      await BackupCrypto.seal({'backup': backup}, code, iterations: 20000),
    );
    // On the Wi-Fi address only, not on mobile data.
    final server = await HttpServer.bind(InternetAddress(ip), 0);
    final t = LanTransferServer._(server, '$ip:${server.port}', code);
    final timer = Timer(lifetime, () => t.stop());
    server.listen((request) async {
      if (request.uri.path != '/backup') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (request.headers.value(proofHeader) != transferProof(code)) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        if (++t._wrong >= maxTries) {
          timer.cancel();
          await t.stop();
        }
        return;
      }
      request.response
        ..headers.contentType = ContentType.json
        ..write(sealed);
      await request.response.close();
      timer.cancel();
      if (!t._done.isCompleted) t._done.complete(true);
      await server.close();
    });
    return t;
  }

  Future<void> stop() async {
    if (!_done.isCompleted) _done.complete(false);
    await _server.close(force: true);
  }

  /// This device's address on the local network.
  static Future<String?> localAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        final ip = a.address;
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
          return ip;
        }
      }
    }
    return null;
  }
}

const proofHeader = 'x-transfer-proof';

/// What the receiver sends to show it knows [code], without sending it.
String transferProof(String code) => hash.sha256
    .convert(utf8.encode('open-smart-home-transfer:${code.trim()}'))
    .toString();

/// Why a backup could not be taken from another device.
enum LanTransferError { unreachable, wrongCode }

/// Takes the backup another device is sending.
Future<String> receiveBackup(String address, String code) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final String body;
  try {
    final request = await client.getUrl(
      Uri.parse('http://${address.trim()}/backup'),
    );
    request.headers.set(proofHeader, transferProof(code));
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode == HttpStatus.forbidden) {
      throw LanTransferError.wrongCode;
    }
    if (response.statusCode != 200) throw LanTransferError.unreachable;
    body = await response.transform(utf8.decoder).join();
  } on LanTransferError {
    rethrow;
  } on Object {
    throw LanTransferError.unreachable;
  } finally {
    client.close(force: true);
  }
  final Object? sealed;
  try {
    sealed = jsonDecode(body);
  } on FormatException {
    throw LanTransferError.unreachable;
  }
  final opened = sealed is Map
      ? await BackupCrypto.open(sealed, code.trim())
      : null;
  final backup = opened?['backup'];
  if (backup == null) throw LanTransferError.wrongCode;
  return backup;
}
