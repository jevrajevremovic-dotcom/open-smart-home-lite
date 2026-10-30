import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import 'lan_transport.dart';

/// The TP-Link account a Tapo (or newer Kasa) device is bound to: the
/// device checks it locally, nothing goes to TP-Link.
@immutable
class TpLinkAccount {
  const TpLinkAccount(this.user, this.password);

  final String user;
  final String password;

  /// As kept in the phone's secure storage.
  String encode() => jsonEncode({'user': user, 'password': password});

  static TpLinkAccount? decode(String? text) {
    if (text == null) return null;
    try {
      final j = jsonDecode(text);
      if (j is Map && j['user'] is String && j['password'] is String) {
        return TpLinkAccount(j['user'] as String, j['password'] as String);
      }
    } on FormatException {
      // Not one.
    }
    return null;
  }
}

/// TP-Link's KLAP: a two-step handshake over HTTP proves both sides know
/// the account, then each request is AES-128-CBC with a per-session key
/// and a SHA-256 signature. Tapo devices and Kasa devices with newer
/// firmware speak it on port 80.
class KlapClient {
  KlapClient(this._http);

  final LanRequests _http;
  final Map<String, _KlapSession> _sessions = {};
  final _random = Random.secure();

  /// [request] (JSON) to the device at [host]; its JSON answer. Throws
  /// `AppFailure` (authentication for a wrong account).
  Future<Map<String, Object?>> send(
    String host,
    TpLinkAccount account,
    Map<String, Object?> request,
  ) async {
    var session = _sessions[host];
    if (session == null || session.expired) {
      session = _sessions[host] = await _handshake(host, account);
    }
    try {
      return await session.send(_http, request);
    } on AppFailure catch (e) {
      // A session the device forgot (it restarted): once more, anew.
      if (e.kind != FailureKind.authentication) rethrow;
      _sessions.remove(host);
      session = _sessions[host] = await _handshake(host, account);
      return session.send(_http, request);
    }
  }

  void forget(String host) => _sessions.remove(host);

  Future<_KlapSession> _handshake(String host, TpLinkAccount account) async {
    final local = Uint8List.fromList([
      for (var i = 0; i < 16; i++) _random.nextInt(256),
    ]);
    final r1 = await _http.send(
      'POST',
      Uri.parse('http://$host/app/handshake1'),
      body: local,
    );
    if (!r1.ok || r1.body.length != 48) {
      throw AppFailure(FailureKind.server, debugMessage: 'klap ${r1.status}');
    }
    final cookie = (r1.headers['set-cookie'] ?? '').split(';').first;
    final remote = r1.body.sublist(0, 16);
    final serverHash = r1.body.sublist(16);
    // v2 (Tapo, newer Kasa), else v1 (older KLAP Kasa).
    for (final v in [2, 1]) {
      final auth = klapAuthHash(account, v);
      final expected = v == 2
          ? _sha256([...local, ...remote, ...auth])
          : _sha256([...local, ...auth]);
      if (!listEquals(expected, serverHash)) continue;
      final r2 = await _http.send(
        'POST',
        Uri.parse('http://$host/app/handshake2'),
        headers: {'cookie': cookie},
        body: v == 2
            ? _sha256([...remote, ...local, ...auth])
            : _sha256([...remote, ...auth]),
      );
      if (!r2.ok) {
        throw const AppFailure(
          FailureKind.authentication,
          debugMessage: 'klap 2',
        );
      }
      return _KlapSession(host, cookie, local, remote, auth);
    }
    throw const AppFailure(
      FailureKind.authentication,
      debugMessage: 'klap: wrong account',
    );
  }
}

/// What both sides prove they know: v2 SHA-256 of SHA-1s, v1 MD5 of MD5s.
Uint8List klapAuthHash(TpLinkAccount a, int version) {
  List<int> u(String s) => utf8.encode(s);
  return Uint8List.fromList(
    version == 2
        ? _sha256([
            ...hash.sha1.convert(u(a.user)).bytes,
            ...hash.sha1.convert(u(a.password)).bytes,
          ])
        : hash.md5.convert([
            ...hash.md5.convert(u(a.user)).bytes,
            ...hash.md5.convert(u(a.password)).bytes,
          ]).bytes,
  );
}

Uint8List _sha256(List<int> b) =>
    Uint8List.fromList(hash.sha256.convert(b).bytes);

class _KlapSession {
  _KlapSession(
    this.host,
    this.cookie,
    List<int> local,
    List<int> remote,
    List<int> auth,
  ) : key = _sha256([...utf8.encode('lsk'), ...local, ...remote, ...auth])
          .sublist(0, 16),
      _sig = _sha256([...utf8.encode('ldk'), ...local, ...remote, ...auth])
          .sublist(0, 28),
      _created = DateTime.now() {
    final iv = _sha256([...utf8.encode('iv'), ...local, ...remote, ...auth]);
    _iv = iv.sublist(0, 12);
    _seq = ByteData.sublistView(iv, 28).getInt32(0);
  }

  final String host;
  final String cookie;
  final Uint8List key;
  final Uint8List _sig;
  late final Uint8List _iv;
  late int _seq;
  final DateTime _created;

  // Devices keep a session for a day; started anew well before.
  bool get expired =>
      DateTime.now().difference(_created) > const Duration(hours: 20);

  static final _aes = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);

  Future<Map<String, Object?>> send(
    LanRequests http,
    Map<String, Object?> request,
  ) async {
    _seq = (_seq + 1).toSigned(32);
    final seq = (ByteData(4)..setInt32(0, _seq)).buffer.asUint8List();
    final nonce = [..._iv, ...seq];
    final secret = SecretKey(key);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(request)),
      secretKey: secret,
      nonce: nonce,
    );
    final signature = _sha256([..._sig, ...seq, ...box.cipherText]);
    final r = await http.send(
      'POST',
      Uri.parse('http://$host/app/request?seq=$_seq'),
      headers: {'cookie': cookie},
      body: [...signature, ...box.cipherText],
    );
    if (r.status == 403 || r.status == 401) {
      throw const AppFailure(FailureKind.authentication, debugMessage: 'klap');
    }
    if (!r.ok || r.body.length <= 32) {
      throw AppFailure(FailureKind.server, debugMessage: 'klap ${r.status}');
    }
    final clear = await _aes.decrypt(
      SecretBox(r.body.sublist(32), nonce: nonce, mac: Mac.empty),
      secretKey: secret,
    );
    final json = jsonDecode(utf8.decode(clear));
    if (json is! Map) {
      throw const AppFailure(FailureKind.parsing, debugMessage: 'klap answer');
    }
    return json.cast<String, Object?>();
  }
}

/// Whether [host] speaks KLAP (it answers the first handshake step).
Future<bool> klapProbe(LanRequests http, String host) async {
  try {
    final r = await http.send(
      'POST',
      Uri.parse('http://$host/app/handshake1'),
      body: List.filled(16, 7),
      timeout: const Duration(seconds: 3),
    );
    return r.ok && r.body.length == 48;
  } on AppFailure {
    return false;
  }
}

final klapClientProvider = Provider<KlapClient>(
  (ref) => KlapClient(ref.watch(lanRequestsProvider)),
);
