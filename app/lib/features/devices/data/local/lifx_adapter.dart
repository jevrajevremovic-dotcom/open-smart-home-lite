import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// LIFX bulbs and strips over their LAN protocol (binary, UDP 56700).
/// Every LIFX takes colour and white; a white-only bulb ignores colour.
class LifxAdapter extends PolledAdapter {
  LifxAdapter(this._udp, {super.pollEvery});

  final LanUdp _udp;

  @override
  String get id => 'lifx';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final state = await lifxAsk(_udp, device.host, device.id, lifxLightGet);
    return [parseLifx(device, state)];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final s = channel.state;
    // What the bulb shows now, changed by the command.
    final hsbk = LifxColor.fromState(s);
    final (type, payload) = switch (command) {
      TurnOn() => (lifxSetPower, lifxPower(true)),
      TurnOff() => (lifxSetPower, lifxPower(false)),
      Toggle() => (lifxSetPower, lifxPower(s.isOn != true)),
      SetBrightness(:final percent) when percent == 0 => (
        lifxSetPower,
        lifxPower(false),
      ),
      SetBrightness(:final percent) => (
        lifxSetColor,
        hsbk.copyWith(brightness: percent / 100).payload(),
      ),
      SetColorTemperature(:final kelvin) => (
        lifxSetColor,
        hsbk
            .copyWith(saturation: 0, kelvin: kelvin.clamp(2500, 9000))
            .payload(),
      ),
      SetRgbColor(:final color) => (
        lifxSetColor,
        LifxColor.fromRgb(color, brightness: hsbk.brightness).payload(),
      ),
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for LIFX',
      ),
    };
    // Colour on a bulb that is off: on as well.
    if (type == lifxSetColor && s.isOn != true) {
      await lifxAsk(
        _udp,
        device.host,
        device.id,
        lifxSetPower,
        lifxPower(true),
      );
    }
    await lifxAsk(_udp, device.host, device.id, type, payload);
  }
}

const lifxGetService = 2;
const lifxStateService = 3;
const lifxLightGet = 101;
const lifxSetColor = 102;
const lifxLightState = 107;
const lifxSetPower = 117;

/// A LIFX message: the 36-byte header and [payload]. [target] is the
/// bulb's MAC (`d073d5…`), empty for everyone.
Uint8List lifxPacket(
  int type, {
  String target = '',
  List<int> payload = const [],
  int sequence = 0,
}) {
  final b = ByteData(36 + payload.length);
  b.setUint16(0, 36 + payload.length, Endian.little);
  // Protocol 1024, addressable; tagged when it is for everyone.
  b.setUint16(2, 1024 | 0x1000 | (target.isEmpty ? 0x2000 : 0), Endian.little);
  b.setUint32(4, 0x4F534854, Endian.little); // our source id: "OSHT"
  for (var i = 0; i < 6 && target.length >= 12; i++) {
    b.setUint8(8 + i, int.parse(target.substring(i * 2, i * 2 + 2), radix: 16));
  }
  b.setUint8(22, 0x01); // a response, please
  b.setUint8(23, sequence & 0xFF);
  b.setUint16(32, type, Endian.little);
  final out = b.buffer.asUint8List();
  out.setRange(36, out.length, payload);
  return out;
}

/// The type, sender MAC and payload of a LIFX message; `null` if it is not one.
({int type, String mac, Uint8List payload})? lifxParse(Uint8List data) {
  if (data.length < 36) return null;
  final b = ByteData.sublistView(data);
  final size = b.getUint16(0, Endian.little);
  if (size != data.length || b.getUint16(2, Endian.little) & 0xFFF != 1024) {
    return null;
  }
  final mac = [
    for (var i = 8; i < 14; i++) data[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return (
    type: b.getUint16(32, Endian.little),
    mac: mac,
    payload: Uint8List.sublistView(data, 36),
  );
}

/// Sends [type] to the bulb and waits for its answer (the bulb's state
/// for colour and power, as asked in the header).
Future<Uint8List> lifxAsk(
  LanUdp udp,
  String host,
  String mac,
  int type, [
  List<int> payload = const [],
]) async {
  final answers = await udp.ask(
    host,
    56700,
    lifxPacket(type, target: mac, payload: payload),
  );
  for (final a in answers) {
    final m = lifxParse(a.data);
    if (m != null) return m.payload;
  }
  throw const AppFailure(FailureKind.timeout, debugMessage: 'lifx');
}

Uint8List lifxPower(bool on) {
  final b = ByteData(6)
    ..setUint16(0, on ? 0xFFFF : 0, Endian.little)
    ..setUint32(2, 300, Endian.little); // ms
  return b.buffer.asUint8List();
}

/// Hue, saturation and brightness (0–1) and white temperature.
class LifxColor {
  const LifxColor(this.hue, this.saturation, this.brightness, this.kelvin);

  /// Degrees.
  final double hue;
  final double saturation;
  final double brightness;
  final int kelvin;

  factory LifxColor.fromState(DeviceState s) {
    final b = (s.brightnessPercent ?? 100) / 100;
    if (s.rgb case final c?) return LifxColor.fromRgb(c, brightness: b);
    return LifxColor(0, 0, b, s.colorTemperatureKelvin ?? 3500);
  }

  factory LifxColor.fromRgb(RgbColor c, {double brightness = 1}) {
    final r = c.red / 255, g = c.green / 255, bl = c.blue / 255;
    final mx = max(r, max(g, bl)), mn = min(r, min(g, bl));
    final d = mx - mn;
    var h = 0.0;
    if (d > 0) {
      h = mx == r
          ? 60 * (((g - bl) / d) % 6)
          : mx == g
          ? 60 * ((bl - r) / d + 2)
          : 60 * ((r - g) / d + 4);
    }
    return LifxColor(
      h < 0 ? h + 360 : h,
      mx == 0 ? 0 : d / mx,
      brightness,
      3500,
    );
  }

  LifxColor copyWith({double? saturation, double? brightness, int? kelvin}) =>
      LifxColor(
        hue,
        saturation ?? this.saturation,
        brightness ?? this.brightness,
        kelvin ?? this.kelvin,
      );

  /// Full brightness and saturation, as the screen shows a colour.
  RgbColor get rgb {
    final h = hue / 60, c = saturation;
    final x = c * (1 - (h % 2 - 1).abs());
    final (r, g, b) = switch (h.floor() % 6) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    final m = 1 - c;
    int v(double f) => ((f + m) * 255).round().clamp(0, 255);
    return RgbColor(v(r), v(g), v(b));
  }

  /// SetColor: reserved byte, HSBK, duration (300 ms).
  Uint8List payload() {
    final b = ByteData(13)
      ..setUint16(1, (hue / 360 * 0xFFFF).round() & 0xFFFF, Endian.little)
      ..setUint16(3, (saturation * 0xFFFF).round(), Endian.little)
      ..setUint16(5, (brightness * 0xFFFF).round(), Endian.little)
      ..setUint16(7, kelvin, Endian.little)
      ..setUint32(9, 300, Endian.little);
    return b.buffer.asUint8List();
  }
}

/// LightState: HSBK, power, label.
SmartHomeDevice parseLifx(ConfiguredDevice device, Uint8List state) {
  if (state.length < 44) {
    throw const AppFailure(FailureKind.server, debugMessage: 'lifx state');
  }
  final b = ByteData.sublistView(state);
  final color = LifxColor(
    b.getUint16(0, Endian.little) / 0xFFFF * 360,
    b.getUint16(2, Endian.little) / 0xFFFF,
    b.getUint16(4, Endian.little) / 0xFFFF,
    b.getUint16(6, Endian.little),
  );
  final on = b.getUint16(10, Endian.little) > 0;
  final label = utf8
      .decode(state.sublist(12, 44), allowMalformed: true)
      .replaceAll('\u0000', '')
      .trim();
  final white = color.saturation < 0.05;
  return SmartHomeDevice(
    id: '${device.key}:light',
    sourceId: device.host,
    deviceId: device.key,
    name: label.isNotEmpty ? label : (device.label ?? 'LIFX'),
    kind: DeviceKind.rgbLight,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'LIFX',
    model: device.model,
    available: true,
    capabilities: const {
      Capability.power,
      Capability.brightness,
      Capability.colorTemperature,
      Capability.rgb,
    },
    state: DeviceState(
      raw: on ? 'on' : 'off',
      isOn: on,
      brightnessPercent: on ? (color.brightness * 100).round() : null,
      colorTemperatureKelvin: on && white ? color.kelvin : null,
      rgb: on && !white ? color.rgb : null,
    ),
    limits: const DeviceLimits(
      minColorTemperatureKelvin: 2500,
      maxColorTemperatureKelvin: 9000,
    ),
  );
}

/// LIFX bulbs on the network (each answers a broadcast GetService), with
/// their label.
Future<List<({String host, String mac, String? label})>> lifxDiscover(
  LanUdp udp,
) async {
  final answers = await udp.ask(
    '255.255.255.255',
    56700,
    lifxPacket(lifxGetService),
    wait: const Duration(seconds: 3),
    first: false,
  );
  final out = <String, ({String host, String mac, String? label})>{};
  for (final a in answers) {
    final m = lifxParse(a.data);
    if (m == null || m.type != lifxStateService || out.containsKey(m.mac)) {
      continue;
    }
    String? label;
    try {
      final s = await lifxAsk(udp, a.host, m.mac, lifxLightGet);
      if (s.length >= 44) {
        label = utf8
            .decode(s.sublist(12, 44), allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
      }
    } on AppFailure {
      // Found, but not telling its name now.
    }
    out[m.mac] = (host: a.host, mac: m.mac, label: label);
  }
  return out.values.toList();
}
