import 'dart:convert';
import 'dart:typed_data';

/// Just enough Protocol Buffers for the ESPHome native API: varints,
/// length-delimited strings and fixed32 (keys, floats). Unknown fields are
/// kept and ignored, so newer devices with more fields still work.
class ProtoWriter {
  final _bytes = BytesBuilder(copy: false);

  Uint8List toBytes() => _bytes.toBytes();

  void _tag(int field, int wireType) =>
      writeVarint(_bytes, field << 3 | wireType);

  void uint(int field, int value) {
    if (value == 0) return;
    _tag(field, 0);
    writeVarint(_bytes, value);
  }

  void boolean(int field, bool value) {
    if (value) uint(field, 1);
  }

  void string(int field, String value) {
    if (value.isEmpty) return;
    final data = utf8.encode(value);
    _tag(field, 2);
    writeVarint(_bytes, data.length);
    _bytes.add(data);
  }

  void fixed32(int field, int value) {
    _tag(field, 5);
    _bytes.add(
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
    );
  }

  void float(int field, double value) {
    if (value == 0) return;
    _tag(field, 5);
    _bytes.add(
      (ByteData(4)..setFloat32(0, value, Endian.little)).buffer.asUint8List(),
    );
  }
}

/// A decoded message: values by field number (repeated fields keep all).
class ProtoMessage {
  ProtoMessage(Uint8List data) {
    var i = 0;
    while (i < data.length) {
      final (tag, afterTag) = readVarint(data, i);
      i = afterTag;
      final field = tag >> 3;
      final Object value;
      switch (tag & 7) {
        case 0:
          final (v, next) = readVarint(data, i);
          value = v;
          i = next;
        case 1:
          if (i + 8 > data.length) throw const FormatException('truncated');
          value = Uint8List.sublistView(data, i, i + 8);
          i += 8;
        case 2:
          final (length, next) = readVarint(data, i);
          if (next + length > data.length) {
            throw const FormatException('truncated');
          }
          value = Uint8List.sublistView(data, next, next + length);
          i = next + length;
        case 5:
          if (i + 4 > data.length) throw const FormatException('truncated');
          value = ByteData.sublistView(
            data,
            i,
            i + 4,
          ).getUint32(0, Endian.little);
          i += 4;
        default:
          throw FormatException('wire type ${tag & 7}');
      }
      (_fields[field] ??= []).add(value);
    }
  }

  final Map<int, List<Object>> _fields = {};

  int uint(int field) => switch (_fields[field]?.last) {
    final int v => v,
    _ => 0,
  };

  bool boolean(int field) => uint(field) != 0;

  /// A fixed32 field as an unsigned int (entity keys).
  int fixed32(int field) => uint(field);

  double float(int field) {
    final v = uint(field);
    return (ByteData(
      4,
    )..setUint32(0, v, Endian.little)).getFloat32(0, Endian.little);
  }

  String string(int field) => switch (_fields[field]?.last) {
    final Uint8List b => utf8.decode(b, allowMalformed: true),
    _ => '',
  };

  List<String> strings(int field) => [
    for (final v in _fields[field] ?? const <Object>[])
      if (v is Uint8List) utf8.decode(v, allowMalformed: true),
  ];

  /// A repeated enum, packed or not.
  List<int> uints(int field) {
    final out = <int>[];
    for (final v in _fields[field] ?? const <Object>[]) {
      if (v is int) {
        out.add(v);
      } else if (v is Uint8List) {
        var i = 0;
        while (i < v.length) {
          final (x, next) = readVarint(v, i);
          out.add(x);
          i = next;
        }
      }
    }
    return out;
  }
}

void writeVarint(BytesBuilder out, int value) {
  var v = value;
  while (v >= 0x80) {
    out.addByte(v & 0x7F | 0x80);
    v >>= 7;
  }
  out.addByte(v);
}

/// (value, index after it). Throws [RangeError] when cut off.
(int, int) readVarint(Uint8List data, int start) {
  var result = 0;
  var shift = 0;
  var i = start;
  while (true) {
    if (i >= data.length) throw RangeError('varint cut off');
    final b = data[i++];
    result |= (b & 0x7F) << shift;
    if (b < 0x80) return (result, i);
    shift += 7;
    if (shift > 63) throw const FormatException('varint too long');
  }
}
