import 'package:flutter/foundation.dart';

/// One Bluetooth LE advertisement as Android heard it.
@immutable
class BleAdvert {
  const BleAdvert({
    required this.address,
    this.name,
    this.rssi,
    this.serviceData = const {},
    this.manufacturerData = const {},
  });

  /// `A4:C1:38:12:34:56`.
  final String address;
  final String? name;
  final int? rssi;

  /// By 16-bit service UUID (`0xFCD2` …).
  final Map<int, Uint8List> serviceData;

  /// By company id (`0xEC88` …).
  final Map<int, Uint8List> manufacturerData;

  /// `a4c138123456`.
  String get id => address.toLowerCase().replaceAll(':', '');
}

/// What a sensor reported, in app units; `null` for what it does not
/// measure.
@immutable
class BleReading {
  const BleReading({
    required this.model,
    this.temperature,
    this.humidity,
    this.battery,
    this.illuminance,
    this.motion,
    this.open,
    this.moisture,
    this.button,
    this.packetId,
  });

  /// `BTHome`, `LYWSD03MMC (pvvx)`, `Govee H5075`, `SwitchBot Meter`…
  final String model;

  /// °C.
  final double? temperature;

  /// %.
  final double? humidity;

  /// %.
  final int? battery;

  /// lx.
  final double? illuminance;
  final bool? motion;

  /// A door or window.
  final bool? open;

  /// A leak.
  final bool? moisture;

  /// `press`, `double_press`, `long_press`…, as the button sent it.
  final String? button;

  /// Repeats of the same advertisement carry the same id.
  final int? packetId;

  bool get isEmpty =>
      temperature == null &&
      humidity == null &&
      illuminance == null &&
      motion == null &&
      open == null &&
      moisture == null &&
      button == null &&
      battery == null;
}

/// The first reading any known format finds in [advert], or `null`.
BleReading? parseAdvert(BleAdvert advert) {
  for (final parse in const [_bthome, _pvvx, _atc, _switchbot, _govee]) {
    final r = parse(advert);
    if (r != null && !r.isEmpty) return r;
  }
  return null;
}

ByteData _view(Uint8List d) => ByteData.sublistView(d);

/// BTHome v2 (https://bthome.io/format/), unencrypted: Shelly BLU,
/// pvvx firmware set to BTHome, many DIY sensors.
BleReading? _bthome(BleAdvert a) {
  final d = a.serviceData[0xFCD2];
  if (d == null || d.isEmpty) return null;
  final info = d[0];
  if (info & 0x01 != 0) return null; // encrypted
  if (info >> 5 != 2) return null; // version 2
  double? temperature, humidity, illuminance;
  int? battery, packet;
  bool? motion, open, moisture;
  String? button;
  final v = _view(d);
  var i = 1;
  // Sizes of the objects this does not read (to skip them).
  const sizes = {
    0x04: 3,
    0x06: 2,
    0x07: 2,
    0x08: 2,
    0x09: 1,
    0x0A: 3,
    0x0B: 3,
    0x0C: 2,
    0x0D: 2,
    0x0E: 2,
    0x0F: 1,
    0x10: 1,
    0x11: 1,
    0x12: 2,
    0x13: 2,
    0x14: 2,
    0x15: 1,
    0x16: 1,
    0x17: 1,
    0x18: 1,
    0x19: 1,
    0x1B: 1,
    0x1C: 1,
    0x1D: 1,
    0x1E: 1,
    0x1F: 1,
    0x22: 1,
    0x23: 1,
    0x24: 1,
    0x25: 1,
    0x26: 1,
    0x27: 1,
    0x28: 1,
    0x29: 1,
    0x2A: 1,
    0x2B: 1,
    0x2C: 1,
    0x3C: 2,
    0x3D: 2,
    0x3E: 4,
    0x3F: 2,
    0x40: 2,
    0x41: 2,
    0x42: 3,
    0x43: 2,
    0x44: 2,
    0x46: 1,
    0x47: 2,
    0x48: 2,
    0x49: 2,
    0x4A: 2,
    0x4B: 3,
    0x4C: 4,
    0x4D: 4,
    0x4E: 4,
    0x4F: 4,
    0x50: 4,
    0x51: 2,
    0x52: 2,
  };
  while (i < d.length) {
    final id = d[i++];
    int need(int n) {
      if (i + n > d.length) throw RangeError('bthome cut off');
      final at = i;
      i += n;
      return at;
    }

    try {
      switch (id) {
        case 0x00:
          packet = d[need(1)];
        case 0x01:
          battery = d[need(1)];
        case 0x02:
          temperature = v.getInt16(need(2), Endian.little) / 100;
        case 0x45:
          temperature = v.getInt16(need(2), Endian.little) / 10;
        case 0x03:
          humidity = v.getUint16(need(2), Endian.little) / 100;
        case 0x2E:
          humidity = d[need(1)].toDouble();
        case 0x05:
          final at = need(3);
          illuminance = (d[at] | d[at + 1] << 8 | d[at + 2] << 16) / 100;
        case 0x21:
          motion = d[need(1)] != 0;
        case 0x2D || 0x1A:
          open = d[need(1)] != 0;
        case 0x20:
          moisture = d[need(1)] != 0;
        case 0x3A:
          button = switch (d[need(1)]) {
            0x00 => null,
            0x01 => 'press',
            0x02 => 'double_press',
            0x03 => 'triple_press',
            0x04 => 'long_press',
            0x80 => 'hold',
            _ => 'press',
          };
        default:
          // An object this does not know has no known size: what came
          // before it is kept, the rest cannot be read.
          final size = sizes[id];
          if (size == null) {
            i = d.length;
          } else {
            need(size);
          }
      }
    } on RangeError {
      break;
    }
  }
  return BleReading(
    model: 'BTHome',
    temperature: temperature,
    humidity: humidity,
    battery: battery,
    illuminance: illuminance,
    motion: motion,
    open: open,
    moisture: moisture,
    button: button,
    packetId: packet,
  );
}

/// pvvx custom firmware (Xiaomi LYWSD03MMC and others), service 0x181A,
/// 15 bytes, little endian.
BleReading? _pvvx(BleAdvert a) {
  final d = a.serviceData[0x181A];
  if (d == null || d.length < 15) return null;
  final v = _view(d);
  return BleReading(
    model: 'LYWSD03MMC (pvvx)',
    temperature: v.getInt16(6, Endian.little) / 100,
    humidity: v.getUint16(8, Endian.little) / 100,
    battery: d[12],
    packetId: d[13],
  );
}

/// ATC1441 firmware, service 0x181A, 13 bytes, big endian.
BleReading? _atc(BleAdvert a) {
  final d = a.serviceData[0x181A];
  if (d == null || d.length != 13) return null;
  final v = _view(d);
  return BleReading(
    model: 'LYWSD03MMC (ATC)',
    temperature: v.getInt16(6) / 10,
    humidity: d[8].toDouble(),
    battery: d[9],
    packetId: d[12],
  );
}

/// SwitchBot Meter / Meter Plus (service data 0xFD3D or the older 0x0D00):
/// type `T`/`i`, battery, temperature (sign, whole, tenths), humidity.
BleReading? _switchbot(BleAdvert a) {
  final d = a.serviceData[0xFD3D] ?? a.serviceData[0x0D00];
  if (d == null || d.length < 6) return null;
  final type = d[0] & 0x7F;
  if (type != 0x54 && type != 0x69) return null; // 'T', 'i'
  final whole = d[4] & 0x7F;
  final tenths = d[3] & 0x0F;
  final sign = d[4] & 0x80 != 0 ? 1 : -1;
  return BleReading(
    model: type == 0x69 ? 'SwitchBot Meter Plus' : 'SwitchBot Meter',
    temperature: sign * (whole + tenths / 10),
    humidity: (d[5] & 0x7F).toDouble(),
    battery: d[2] & 0x7F,
  );
}

/// Govee H5072/H5075/H5101/H5102 thermometers (company 0xEC88): three
/// bytes packing temperature and humidity, then the battery.
BleReading? _govee(BleAdvert a) {
  final d = a.manufacturerData[0xEC88];
  if (d == null || d.length < 5) return null;
  var packed = d[1] << 16 | d[2] << 8 | d[3];
  final negative = packed & 0x800000 != 0;
  if (negative) packed &= 0x7FFFFF;
  final t = packed ~/ 1000 / 10;
  return BleReading(
    model: 'Govee',
    temperature: negative ? -t : t,
    humidity: (packed % 1000) / 10,
    battery: d[4],
  );
}
