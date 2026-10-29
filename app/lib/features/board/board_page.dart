import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Logical page size: every device draws in these units and scales them to
/// its screen, so a page looks the same on the wall tablet and a phone.
const double boardWidth = 1600;
const double boardHeight = 1000;

/// Pen colours by index, so "ink" can follow the theme (dark on light
/// paper, light on dark paper). Index 0 is ink.
const List<Color> boardColors = [
  Color(0xFF2B2622), // ink
  Color(0xFFD32F2F),
  Color(0xFF1E6FD9),
  Color(0xFF2E9D4E),
  Color(0xFFE08A00),
  Color(0xFF8E44AD),
];

/// Light version of ink for dark paper.
const Color boardInkOnDark = Color(0xFFF1EBE2);

/// Pen widths in logical units.
const List<double> boardWidths = [4, 9, 18];

/// One pen line.
@immutable
class BoardStroke {
  const BoardStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  /// Index into [boardColors].
  final int color;
  final double width;

  /// Logical coordinates (0…[boardWidth], 0…[boardHeight]).
  final List<Offset> points;

  Map<String, Object?> toJson() => {
    'c': color,
    'w': width,
    // Whole units are plenty and keep pages small.
    'p': [
      for (final p in points) ...[p.dx.round(), p.dy.round()],
    ],
  };

  static BoardStroke? tryParse(Object? json) {
    if (json is! Map) return null;
    final c = json['c'];
    final w = json['w'];
    final p = json['p'];
    if (c is! int || w is! num || p is! List || p.length < 2) return null;
    final points = <Offset>[];
    for (var i = 0; i + 1 < p.length; i += 2) {
      final x = p[i];
      final y = p[i + 1];
      if (x is! num || y is! num) return null;
      points.add(Offset(x.toDouble(), y.toDouble()));
    }
    return BoardStroke(
      color: c.clamp(0, boardColors.length - 1),
      width: w.toDouble().clamp(1, 60),
      points: points,
    );
  }

  /// Whether [at] is within [radius] of this line (for the eraser).
  bool hits(Offset at, double radius) {
    final r = radius + width / 2;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = i + 1 < points.length ? points[i + 1] : a;
      if (_distanceToSegment(at, a, b) <= r) return true;
    }
    return false;
  }
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// One page of the board.
@immutable
class BoardPage {
  const BoardPage({required this.id, this.strokes = const []});

  /// Stable across saves (each save is a new image in Home Assistant).
  final String id;
  final List<BoardStroke> strokes;

  BoardPage copyWith({List<BoardStroke>? strokes}) =>
      BoardPage(id: id, strokes: strokes ?? this.strokes);

  String toJsonString() => jsonEncode({
    'v': 1,
    'w': boardWidth,
    'h': boardHeight,
    's': [for (final s in strokes) s.toJson()],
  });

  static BoardPage? tryParse(String id, String json) {
    try {
      final data = jsonDecode(json);
      if (data is! Map || data['v'] != 1 || data['s'] is! List) return null;
      return BoardPage(
        id: id,
        strokes: [for (final s in data['s'] as List) ?BoardStroke.tryParse(s)],
      );
    } on FormatException {
      return null;
    }
  }
}

/// Draws [strokes] scaled from logical units by [scale].
void paintStrokes(
  Canvas canvas,
  List<BoardStroke> strokes, {
  required double scale,
  required bool dark,
}) {
  for (final s in strokes) {
    final color = s.color == 0 && dark ? boardInkOnDark : boardColors[s.color];
    final paint = Paint()
      ..color = color
      ..strokeWidth = s.width * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final pts = s.points;
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.first * scale,
        s.width * scale / 2,
        paint..style = PaintingStyle.fill,
      );
      continue;
    }
    // Smooth: quadratic curves through the midpoints.
    final path = Path()..moveTo(pts[0].dx * scale, pts[0].dy * scale);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(
        pts[i].dx * scale,
        pts[i].dy * scale,
        mid.dx * scale,
        mid.dy * scale,
      );
    }
    path.lineTo(pts.last.dx * scale, pts.last.dy * scale);
    canvas.drawPath(path, paint);
  }
}

/// Light paper colour of saved pictures.
const Color boardPaper = Color(0xFFFBF8F2);

/// A PNG of [page] (half size, light paper) with the page itself inside, so
/// Home Assistant shows a normal picture and the app can edit it again.
Future<Uint8List> encodeBoardPng(BoardPage page) async {
  const scale = 0.5;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, boardWidth * scale, boardHeight * scale),
    Paint()..color = boardPaper,
  );
  paintStrokes(canvas, page.strokes, scale: scale, dark: false);
  final image = await recorder.endRecording().toImage(
    (boardWidth * scale).round(),
    (boardHeight * scale).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return embedBoardData(data!.buffer.asUint8List(), page.toJsonString());
}

const _keyword = 'osh-board';
const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Inserts a `tEXt` chunk (keyword `osh-board`, base64 of the UTF-8 JSON)
/// right after the PNG header chunk.
Uint8List embedBoardData(Uint8List png, String json) {
  if (png.length < 33 || !listEquals(png.sublist(0, 8), _pngSignature)) {
    throw const FormatException('not a PNG');
  }
  final ihdrLength = ByteData.sublistView(png, 8, 12).getUint32(0);
  final afterIhdr = 8 + 12 + ihdrLength;
  final data = Uint8List.fromList([
    ...ascii.encode(_keyword),
    0,
    ...ascii.encode(base64.encode(utf8.encode(json))),
  ]);
  final type = ascii.encode('tEXt');
  final chunk = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(type)
    ..add(data)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, _crc32([...type, ...data]))).buffer.asUint8List(),
    );
  return Uint8List.fromList([
    ...png.sublist(0, afterIhdr),
    ...chunk.toBytes(),
    ...png.sublist(afterIhdr),
  ]);
}

/// The JSON put in by [embedBoardData], or `null` (not one of ours).
String? extractBoardData(Uint8List png) {
  if (png.length < 8 || !listEquals(png.sublist(0, 8), _pngSignature)) {
    return null;
  }
  var at = 8;
  while (at + 12 <= png.length) {
    final length = ByteData.sublistView(png, at, at + 4).getUint32(0);
    final type = ascii.decode(png.sublist(at + 4, at + 8), allowInvalid: true);
    final start = at + 8;
    final end = start + length;
    if (end + 4 > png.length) return null;
    if (type == 'tEXt') {
      final body = png.sublist(start, end);
      final zero = body.indexOf(0);
      if (zero > 0 && ascii.decode(body.sublist(0, zero)) == _keyword) {
        try {
          return utf8.decode(
            base64.decode(ascii.decode(body.sublist(zero + 1))),
          );
        } on FormatException {
          return null;
        }
      }
    }
    if (type == 'IEND') return null;
    at = end + 4;
  }
  return null;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// CRC-32 as PNG chunks use it.
@visibleForTesting
int boardCrc32(List<int> bytes) => _crc32(bytes);

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
