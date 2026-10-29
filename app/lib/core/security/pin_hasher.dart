import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 for the local kiosk exit PIN.
///
/// The PIN only guards leaving kiosk mode on this device (it is not a
/// server credential), but it is still never stored in clear text.
abstract final class PinHasher {
  static const int iterations = 20000;

  static final RegExp validPin = RegExp(r'^[0-9]{4,8}$');

  static String newSalt([Random? random]) {
    final r = random ?? Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String pin, String salt, {int rounds = iterations}) =>
      base64Encode(_pbkdf2(utf8.encode(pin), base64Decode(salt), rounds, 32));

  /// Constant-time comparison of [pin]'s hash with [expectedHash].
  static bool verify(
    String pin,
    String salt,
    String expectedHash, {
    int rounds = iterations,
  }) {
    final actual = base64Decode(hash(pin, salt, rounds: rounds));
    final expected = base64Decode(expectedHash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int rounds,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    for (var block = 1; out.length < length; block++) {
      final blockIndex = ByteData(4)..setUint32(0, block);
      var u = hmac.convert([...salt, ...blockIndex.buffer.asUint8List()]).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < rounds; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }
}
