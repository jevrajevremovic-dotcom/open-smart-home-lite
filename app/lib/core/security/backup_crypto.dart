import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Secrets (device passwords, keys) in a backup: encrypted with a key
/// derived from the household's password (PBKDF2-HMAC-SHA256), then
/// AES-256-GCM. Without the password they cannot be read; a wrong one is
/// told apart (GCM's tag does not match).
abstract final class BackupCrypto {
  static const _iterations = 100000;

  static Pbkdf2 _kdf(int iterations) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);

  static List<int> _random(int n) {
    final r = Random.secure();
    return [for (var i = 0; i < n; i++) r.nextInt(256)];
  }

  static Future<Map<String, Object?>> seal(
    Map<String, String> secrets,
    String password, {
    int iterations = _iterations,
  }) async {
    final salt = _random(16);
    final key = await _kdf(iterations)
        .deriveKeyFromPassword(password: password, nonce: salt);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(secrets)),
      secretKey: key,
      nonce: _random(12),
    );
    return {
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'data': base64.encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// The secrets, or `null` for a wrong password (or a broken backup).
  static Future<Map<String, String>?> open(
    Map<Object?, Object?> sealed,
    String password,
  ) async {
    try {
      final iterations = sealed['iterations'] as int;
      final salt = base64.decode(sealed['salt']! as String);
      final nonce = base64.decode(sealed['nonce']! as String);
      final data = base64.decode(sealed['data']! as String);
      if (data.length < 16 || sealed['kdf'] != 'pbkdf2-sha256') return null;
      final key = await _kdf(iterations)
          .deriveKeyFromPassword(password: password, nonce: salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          data.sublist(0, data.length - 16),
          nonce: nonce,
          mac: Mac(data.sublist(data.length - 16)),
        ),
        secretKey: key,
      );
      final json = jsonDecode(utf8.decode(clear));
      if (json is! Map) return null;
      return {
        for (final e in json.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    } on SecretBoxAuthenticationError {
      return null;
    } on Object {
      return null;
    }
  }
}
