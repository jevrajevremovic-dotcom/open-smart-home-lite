import 'dart:typed_data';

/// Synthetic camera frames for mock mode: a simple drawn yard scene with a
/// moving object and a seconds bar, encoded as PNG in pure Dart (no codec
/// dependency, works on every platform). Clearly artificial on purpose.
Uint8List mockCameraFrame(int camera, DateTime time) {
  const w = 320, h = 180;
  final px = Uint8List(w * h * 3);
  final second = time.second + time.millisecond / 1000;
  final skies = [
    (0x6E, 0xA8, 0xE0, 0xC9, 0xE4, 0xF7), // day
    (0x2B, 0x3A, 0x6B, 0x86, 0x6F, 0x9E), // dusk
    (0x9B, 0xC4, 0xD8, 0xE8, 0xEF, 0xF2), // overcast
  ];
  final (r1, g1, b1, r2, g2, b2) = skies[camera % skies.length];
  int mix(int a, int b, double t) => (a + (b - a) * t).round();

  void set(int x, int y, int r, int g, int b) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = (y * w + x) * 3;
    px[i] = r;
    px[i + 1] = g;
    px[i + 2] = b;
  }

  void rect(int x0, int y0, int x1, int y1, int r, int g, int b) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        set(x, y, r, g, b);
      }
    }
  }

  final horizon = (h * 0.58).round();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (y < horizon) {
        final t = y / horizon;
        set(x, y, mix(r1, r2, t), mix(g1, g2, t), mix(b1, b2, t));
      } else {
        // Grass with a little texture.
        final n = ((x * 7 + y * 13) % 11) - 5;
        set(x, y, 0x4C + n, 0x8C + n * 2, 0x3A + n);
      }
    }
  }
  // Fence, house and path differ per camera.
  for (var x = 0; x < w; x += 18) {
    rect(x, horizon - 22, x + 4, horizon + 4, 0x8A, 0x6A, 0x4A);
  }
  rect(0, horizon - 14, w, horizon - 11, 0x8A, 0x6A, 0x4A);
  final hx = 40 + camera * 70;
  rect(hx, horizon - 70, hx + 110, horizon, 0xD9, 0xCF, 0xC0);
  rect(hx + 40, horizon - 38, hx + 62, horizon, 0x6B, 0x4A, 0x32);
  rect(hx + 12, horizon - 56, hx + 32, horizon - 38, 0x9F, 0xC7, 0xE8);
  rect(hx + 78, horizon - 56, hx + 98, horizon - 38, 0x9F, 0xC7, 0xE8);
  // Roof: rows getting narrower towards the ridge.
  final top = horizon - 70;
  for (var y = 0; y < 28; y++) {
    rect(
      hx - 8 + y * 2,
      top - y,
      hx + 118 - y * 2,
      top - y + 1,
      0xA8,
      0x45,
      0x32,
    );
  }
  rect(hx + 38, horizon, hx + 64, h, 0xBF, 0xB2, 0x9C);
  // A "cat" crossing the yard, so refreshes are visible.
  final cx = ((second / 60) * (w + 40)).round() - 20;
  rect(cx, h - 40, cx + 22, h - 30, 0x33, 0x2E, 0x2A);
  rect(cx + 18, h - 46, cx + 26, h - 38, 0x33, 0x2E, 0x2A);
  // Seconds bar.
  rect(0, h - 4, (second / 60 * w).round(), h, 0xFF, 0xFF, 0xFF);
  return _encodePng(w, h, px);
}

/// Demo album art: two colours picked from [title], a record in the
/// middle. Each demo song gets its own look.
Uint8List mockAlbumArt(String title) {
  const size = 200;
  final px = Uint8List(size * size * 3);
  const palettes = [
    (0xE2, 0x6D, 0x3B, 0x5B, 0x1E, 0x4F), // orange → plum
    (0x2E, 0x8B, 0xC0, 0x14, 0x2C, 0x5C), // blue → navy
    (0x6C, 0xB8, 0x6A, 0x1E, 0x4D, 0x3A), // green → forest
  ];
  final (r1, g1, b1, r2, g2, b2) =
      palettes[title.codeUnits.fold(0, (a, c) => a + c) % palettes.length];
  int mix(int a, int b, double t) => (a + (b - a) * t).round();
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      final dx = x - size / 2, dy = y - size / 2;
      final d2 = dx * dx + dy * dy;
      final i = (y * size + x) * 3;
      if (d2 < 70 * 70 && d2 > 10 * 10) {
        // The record: dark with faint grooves.
        final groove = (d2 ~/ 160).isEven ? 0x22 : 0x2C;
        px[i] = groove;
        px[i + 1] = groove;
        px[i + 2] = groove;
      } else if (d2 <= 10 * 10) {
        px[i] = r1;
        px[i + 1] = g1;
        px[i + 2] = b1;
      } else {
        px[i] = mix(r1, r2, t);
        px[i + 1] = mix(g1, g2, t);
        px[i + 2] = mix(b1, b2, t);
      }
    }
  }
  return _encodePng(size, size, px);
}

Uint8List _encodePng(int w, int h, Uint8List rgb) {
  // Raw scanlines with filter byte 0.
  final raw = Uint8List(h * (w * 3 + 1));
  for (var y = 0; y < h; y++) {
    raw.setRange(y * (w * 3 + 1) + 1, (y + 1) * (w * 3 + 1), rgb, y * w * 3);
  }
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32([...typeBytes, ...data])));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, 2, 0, 0, 0]);
  chunk('IDAT', _zlibStored(raw));
  chunk('IEND', const []);
  return out.takeBytes();
}

/// zlib stream with uncompressed ("stored") deflate blocks.
List<int> _zlibStored(Uint8List data) {
  final out = BytesBuilder()..add(const [0x78, 0x01]);
  var pos = 0;
  do {
    final len = (data.length - pos).clamp(0, 0xFFFF);
    final last = pos + len >= data.length;
    out
      ..addByte(last ? 1 : 0)
      ..add([len & 0xFF, len >> 8, ~len & 0xFF, (~len >> 8) & 0xFF])
      ..add(Uint8List.sublistView(data, pos, pos + len));
    pos += len;
  } while (pos < data.length);
  var a = 1, b = 0;
  for (final v in data) {
    a = (a + v) % 65521;
    b = (b + a) % 65521;
  }
  out.add(_u32((b << 16) | a));
  return out.takeBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
