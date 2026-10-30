import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES as devices use it (Tuya: ECB; Xiaomi: CBC), with PKCS#7 padding.
/// Small payloads only; synchronous.
Uint8List aesEcbEncrypt(List<int> key, List<int> data, {bool pad = true}) =>
    _run(
      ECBBlockCipher(AESEngine())..init(true, KeyParameter(_u8(key))),
      pad ? pkcs7Pad(data) : _u8(data),
    );

/// Throws [FormatException] when [data] is not whole blocks or not padded.
Uint8List aesEcbDecrypt(List<int> key, List<int> data, {bool pad = true}) {
  final clear = _run(
    ECBBlockCipher(AESEngine())..init(false, KeyParameter(_u8(key))),
    _u8(data),
  );
  return pad ? pkcs7Unpad(clear) : clear;
}

Uint8List aesCbcEncrypt(List<int> key, List<int> iv, List<int> data) => _run(
  CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(_u8(key)), _u8(iv))),
  pkcs7Pad(data),
);

Uint8List aesCbcDecrypt(List<int> key, List<int> iv, List<int> data) =>
    pkcs7Unpad(
      _run(
        CBCBlockCipher(AESEngine())
          ..init(false, ParametersWithIV(KeyParameter(_u8(key)), _u8(iv))),
        _u8(data),
      ),
    );

Uint8List pkcs7Pad(List<int> data) {
  final n = 16 - data.length % 16;
  return Uint8List.fromList([...data, for (var i = 0; i < n; i++) n]);
}

Uint8List pkcs7Unpad(Uint8List data) {
  if (data.isEmpty) throw const FormatException('empty');
  final n = data.last;
  if (n < 1 || n > 16 || n > data.length) {
    throw const FormatException('bad padding');
  }
  for (var i = data.length - n; i < data.length; i++) {
    if (data[i] != n) throw const FormatException('bad padding');
  }
  return Uint8List.sublistView(data, 0, data.length - n);
}

Uint8List _run(BlockCipher cipher, Uint8List input) {
  if (input.length % 16 != 0) throw const FormatException('not whole blocks');
  final out = Uint8List(input.length);
  for (var i = 0; i < input.length; i += 16) {
    cipher.processBlock(input, i, out, i);
  }
  return out;
}

Uint8List _u8(List<int> b) => b is Uint8List ? b : Uint8List.fromList(b);
