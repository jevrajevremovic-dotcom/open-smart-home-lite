import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// `Noise_NNpsk0_25519_ChaChaPoly_SHA256`, as the ESPHome native API uses it
/// when the device has an encryption key (a 32-byte pre-shared key):
///
///     -> psk, e
///     <- e, ee
///
/// Only what the handshake needs, after the Noise Protocol Framework
/// (revision 34), sections 5 and 9.
class NoiseHandshake {
  NoiseHandshake._(this._psk, this._initiator);

  /// The app's side.
  factory NoiseHandshake.initiator(Uint8List psk) =>
      NoiseHandshake._(psk, true);

  /// The device's side, for tests.
  @visibleForTesting
  factory NoiseHandshake.responder(Uint8List psk) =>
      NoiseHandshake._(psk, false);

  static final prologue = Uint8List.fromList([
    ...ascii.encode('NoiseAPIInit'),
    0,
    0,
  ]);
  static const _name = 'Noise_NNpsk0_25519_ChaChaPoly_SHA256';
  static final _x25519 = X25519();

  final Uint8List _psk;
  final bool _initiator;
  late final _SymmetricState _state = _SymmetricState(_name)..mixHash(prologue);
  SimpleKeyPair? _e;

  /// The first message (initiator), `e.pub ‖ tag`.
  Future<Uint8List> writeFirst() async {
    _state.mixKeyAndHash(_psk);
    return _writeEphemeral();
  }

  /// Reads the first message (responder) and writes the answer.
  @visibleForTesting
  Future<Uint8List> readFirstAndAnswer(Uint8List message) async {
    _state.mixKeyAndHash(_psk);
    final re = await _readEphemeral(message);
    final answer = await _writeEphemeral(beforePayload: () => _ee(re));
    return answer;
  }

  /// Reads the answer (initiator).
  Future<void> readAnswer(Uint8List message) async {
    final re = await _readEphemeral(message, beforePayload: _ee);
    if (re.isEmpty) throw const FormatException('empty answer');
  }

  /// The transport ciphers once the handshake is done.
  (NoiseCipher send, NoiseCipher receive) split() {
    final (k1, k2) = _state.split();
    return _initiator
        ? (NoiseCipher(k1), NoiseCipher(k2))
        : (NoiseCipher(k2), NoiseCipher(k1));
  }

  Future<Uint8List> _writeEphemeral({
    Future<void> Function()? beforePayload,
  }) async {
    final e = _e = await _x25519.newKeyPair();
    final pub = Uint8List.fromList((await e.extractPublicKey()).bytes);
    _state
      ..mixHash(pub)
      ..mixKey(pub); // psk mode: `e` also mixes the key
    await beforePayload?.call();
    final tag = await _state.encryptAndHash(Uint8List(0));
    return Uint8List.fromList([...pub, ...tag]);
  }

  Future<Uint8List> _readEphemeral(
    Uint8List message, {
    Future<void> Function(Uint8List re)? beforePayload,
  }) async {
    if (message.length < 32) throw const FormatException('short message');
    final re = Uint8List.sublistView(message, 0, 32);
    _state
      ..mixHash(re)
      ..mixKey(re);
    await beforePayload?.call(re);
    await _state.decryptAndHash(Uint8List.sublistView(message, 32));
    return re;
  }

  Future<void> _ee(Uint8List re) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: _e!,
      remotePublicKey: SimplePublicKey(re, type: KeyPairType.x25519),
    );
    _state.mixKey(Uint8List.fromList(await shared.extractBytes()));
  }
}

/// One direction of the transport: ChaCha20-Poly1305 with a counting
/// nonce and no associated data.
class NoiseCipher {
  NoiseCipher(this._key);

  final Uint8List _key;
  int _n = 0;

  Future<Uint8List> encrypt(Uint8List plaintext) =>
      _encrypt(_key, _n++, Uint8List(0), plaintext);

  Future<Uint8List> decrypt(Uint8List ciphertext) =>
      _decrypt(_key, _n++, Uint8List(0), ciphertext);
}

final _aead = Chacha20.poly1305Aead();

/// 96-bit nonce: 32 zero bits, then the counter (little endian).
List<int> _nonce(int n) =>
    (ByteData(12)..setUint64(4, n, Endian.little)).buffer.asUint8List();

Future<Uint8List> _encrypt(
  Uint8List key,
  int n,
  Uint8List ad,
  Uint8List plaintext,
) async {
  final box = await _aead.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: _nonce(n),
    aad: ad,
  );
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

Future<Uint8List> _decrypt(
  Uint8List key,
  int n,
  Uint8List ad,
  Uint8List ciphertext,
) async {
  if (ciphertext.length < 16) throw const FormatException('short ciphertext');
  final split = ciphertext.length - 16;
  try {
    return Uint8List.fromList(
      await _aead.decrypt(
        SecretBox(
          ciphertext.sublist(0, split),
          nonce: _nonce(n),
          mac: Mac(ciphertext.sublist(split)),
        ),
        secretKey: SecretKey(key),
        aad: ad,
      ),
    );
  } on SecretBoxAuthenticationError {
    // Wrong key (or a broken message).
    throw const NoiseAuthenticationError();
  }
}

/// The device's answer could not be decrypted: usually a wrong key.
class NoiseAuthenticationError implements Exception {
  const NoiseAuthenticationError();
}

class _SymmetricState {
  _SymmetricState(String protocolName) {
    final name = ascii.encode(protocolName);
    _h = name.length <= 32 ? (Uint8List(32)..setAll(0, name)) : _sha256(name);
    _ck = _h;
  }

  late Uint8List _h;
  late Uint8List _ck;
  Uint8List? _k;
  int _n = 0;

  void mixHash(List<int> data) => _h = _sha256([..._h, ...data]);

  void mixKey(Uint8List ikm) {
    final [ck, k] = _hkdf(_ck, ikm, 2);
    _ck = ck;
    _k = k;
    _n = 0;
  }

  void mixKeyAndHash(Uint8List ikm) {
    final [ck, h, k] = _hkdf(_ck, ikm, 3);
    _ck = ck;
    mixHash(h);
    _k = k;
    _n = 0;
  }

  Future<Uint8List> encryptAndHash(Uint8List plaintext) async {
    final c = _k == null ? plaintext : await _encrypt(_k!, _n++, _h, plaintext);
    mixHash(c);
    return c;
  }

  Future<Uint8List> decryptAndHash(Uint8List ciphertext) async {
    final p = _k == null
        ? ciphertext
        : await _decrypt(_k!, _n++, _h, ciphertext);
    mixHash(ciphertext);
    return p;
  }

  (Uint8List, Uint8List) split() {
    final [k1, k2] = _hkdf(_ck, Uint8List(0), 2);
    return (k1, k2);
  }
}

Uint8List _sha256(List<int> data) =>
    Uint8List.fromList(crypto.sha256.convert(data).bytes);

Uint8List _hmac(List<int> key, List<int> data) =>
    Uint8List.fromList(crypto.Hmac(crypto.sha256, key).convert(data).bytes);

List<Uint8List> _hkdf(Uint8List chainingKey, Uint8List ikm, int outputs) {
  final temp = _hmac(chainingKey, ikm);
  final out = <Uint8List>[];
  var previous = <int>[];
  for (var i = 1; i <= outputs; i++) {
    previous = _hmac(temp, [...previous, i]);
    out.add(Uint8List.fromList(previous));
  }
  return out;
}
