import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'aes.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

// Xiaomi's miIO (Mi Home): JSON-RPC over UDP 54321, encrypted with the
// device's token (32 hex characters, taken once from the Mi Home account,
// e.g. with Xiaomi Cloud Tokens Extractor). Supported: plugs and lights
// that follow Xiaomi's MIoT spec (power on service 2), older Chuangmi
// plugs, and Roborock vacuums.

/// The 32-byte "hello" every device answers with its id and clock.
final miioHello = Uint8List.fromList([
  0x21, 0x31, 0x00, 0x20, //
  for (var i = 0; i < 28; i++) 0xFF,
]);

/// AES key and IV from the token: MD5(token), MD5(key + token).
({Uint8List key, Uint8List iv}) miioKeys(List<int> token) {
  final key = Uint8List.fromList(hash.md5.convert(token).bytes);
  final iv = Uint8List.fromList(hash.md5.convert([...key, ...token]).bytes);
  return (key: key, iv: iv);
}

/// A request packet to device [id] at its clock [stamp].
Uint8List miioPacket(
  List<int> token,
  int id,
  int stamp,
  Map<String, Object?> json,
) {
  final k = miioKeys(token);
  final body = aesCbcEncrypt(k.key, k.iv, utf8.encode(jsonEncode(json)));
  final head = ByteData(32)
    ..setUint16(0, 0x2131)
    ..setUint16(2, 32 + body.length)
    ..setUint32(8, id)
    ..setUint32(12, stamp);
  final h = head.buffer.asUint8List();
  final checksum = hash.md5.convert([...h.sublist(0, 16), ...token, ...body]);
  h.setRange(16, 32, checksum.bytes);
  return Uint8List.fromList([...h, ...body]);
}

/// The device id and clock in a packet's header.
({int id, int stamp})? miioHeader(Uint8List data) {
  if (data.length < 32) return null;
  final b = ByteData.sublistView(data);
  if (b.getUint16(0) != 0x2131) return null;
  return (id: b.getUint32(8), stamp: b.getUint32(12));
}

/// The JSON in an answer; `null` when it is not readable with [token].
Map<String, Object?>? miioOpen(Uint8List data, List<int> token) {
  if (data.length <= 32) return null;
  final k = miioKeys(token);
  try {
    var clear = aesCbcDecrypt(k.key, k.iv, data.sublist(32));
    // Some firmware pads the JSON with NULs.
    final end = clear.indexOf(0);
    if (end >= 0) clear = clear.sublist(0, end);
    final j = jsonDecode(utf8.decode(clear));
    return j is Map ? j.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// Token as bytes; throws for anything but 32 hex characters.
Uint8List miioToken(String hex) {
  final t = hex.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(t)) {
    throw const AppFailure(FailureKind.validation, debugMessage: 'miio token');
  }
  return Uint8List.fromList([
    for (var i = 0; i < 32; i += 2) int.parse(t.substring(i, i + 2), radix: 16),
  ]);
}

class MiioClient {
  MiioClient(this._udp);

  final LanUdp _udp;
  int _id = 0;

  /// [method]'s `result`. Throws `AppFailure`: authentication when the
  /// answer cannot be read (a wrong token), server for an `error`.
  Future<Object?> call(
    String host,
    List<int> token,
    String method, [
    Object params = const [],
  ]) async {
    final hello = await _udp.ask(host, 54321, miioHello);
    final h = hello.isEmpty ? null : miioHeader(hello.first.data);
    if (h == null) {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'miio hello');
    }
    final id = ++_id;
    final answers = await _udp.ask(
      host,
      54321,
      miioPacket(token, h.id, h.stamp + 1, {
        'id': id,
        'method': method,
        'params': params,
      }),
      wait: const Duration(seconds: 3),
    );
    if (answers.isEmpty) {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'miio');
    }
    final json = miioOpen(answers.first.data, token);
    if (json == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'miio: wrong token',
      );
    }
    if (json['error'] case final Object error) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'miio $method: $error',
      );
    }
    return json['result'];
  }

  /// MIoT properties (`[(siid, piid)]`) → values, `null` where not read.
  Future<List<Object?>> properties(
    String host,
    List<int> token,
    List<(int, int)> props,
  ) async {
    final r = await call(host, token, 'get_properties', [
      for (final (s, p) in props) {'did': '$s-$p', 'siid': s, 'piid': p},
    ]);
    final values = {
      for (final e in (r as List?) ?? const [])
        if (e is Map && e['code'] == 0) '${e['siid']}-${e['piid']}': e['value'],
    };
    return [for (final (s, p) in props) values['$s-$p']];
  }

  Future<void> setProperty(
    String host,
    List<int> token,
    int siid,
    int piid,
    Object value,
  ) async {
    await call(host, token, 'set_properties', [
      {'did': '$siid-$piid', 'siid': siid, 'piid': piid, 'value': value},
    ]);
  }
}

enum MiioKind { vacuum, light, legacyPlug, plug }

MiioKind miioKind(String? model) {
  final m = (model ?? '').toLowerCase();
  if (m.contains('vacuum')) return MiioKind.vacuum;
  if (m.contains('.light.') || m.contains('.lamp')) return MiioKind.light;
  // The first Chuangmi plugs speak the older get_prop.
  if (RegExp(r'^chuangmi\.plug\.(m1|m3|v1|v2|v3|hmi205|hmi206)$').hasMatch(m)) {
    return MiioKind.legacyPlug;
  }
  return MiioKind.plug;
}

/// Roborock's state numbers.
String roborockState(int? s) => switch (s) {
  5 || 7 || 11 || 16 || 17 || 18 => 'cleaning',
  6 || 15 => 'returning',
  10 => 'paused',
  8 || 100 => 'docked',
  12 => 'error',
  _ => 'idle',
};

class MiioAdapter extends PolledAdapter {
  MiioAdapter(
    this._client, {
    this.tokens,
    super.pollEvery = const Duration(seconds: 10),
  });

  final MiioClient _client;
  final Future<String?> Function(String key)? tokens;

  @override
  String get id => 'miio';

  Future<Uint8List> _token(ConfiguredDevice d) async {
    final t = await tokens?.call(d.key);
    if (t == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'miio: no token',
      );
    }
    return miioToken(t);
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final token = await _token(device);
    final host = device.host;
    switch (miioKind(device.model)) {
      case MiioKind.vacuum:
        final r = await _client.call(host, token, 'get_status');
        final s = r is List && r.isNotEmpty && r.first is Map
            ? (r.first as Map).cast<String, Object?>()
            : const <String, Object?>{};
        return [parseMiio(device, vacuum: s)];
      case MiioKind.legacyPlug:
        final r = await _client.call(host, token, 'get_prop', ['power']);
        final on = r is List && r.isNotEmpty && r.first == 'on';
        return [parseMiio(device, on: on)];
      case MiioKind.light:
        final v = await _client.properties(host, token, const [
          (2, 1),
          (2, 2),
          (2, 3),
        ]);
        return [
          parseMiio(
            device,
            on: v[0] == true,
            brightness: (v[1] as num?)?.round(),
            kelvin: (v[2] as num?)?.round(),
          ),
        ];
      case MiioKind.plug:
        final v = await _client.properties(host, token, const [(2, 1)]);
        return [parseMiio(device, on: v[0] == true)];
    }
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final token = await _token(device);
    final host = device.host;
    final kind = miioKind(device.model);
    final on = switch (command) {
      TurnOn() => true,
      TurnOff() => false,
      Toggle() => channel.state.isOn != true,
      _ => null,
    };
    switch ((kind, command)) {
      case (MiioKind.vacuum, VacuumStart()):
        await _client.call(host, token, 'app_start');
      case (MiioKind.vacuum, VacuumPause()):
        await _client.call(host, token, 'app_pause');
      case (MiioKind.vacuum, VacuumReturnHome()):
        await _client.call(host, token, 'app_charge');
      case (MiioKind.legacyPlug, _) when on != null:
        await _client.call(host, token, 'set_power', [on ? 'on' : 'off']);
      case (MiioKind.light, SetBrightness(:final percent)) when percent > 0:
        await _client.setProperty(host, token, 2, 1, true);
        await _client.setProperty(host, token, 2, 2, percent.clamp(1, 100));
      case (MiioKind.light, SetBrightness()):
        await _client.setProperty(host, token, 2, 1, false);
      case (MiioKind.light, SetColorTemperature(:final kelvin)):
        await _client.setProperty(host, token, 2, 1, true);
        await _client.setProperty(host, token, 2, 3, kelvin.clamp(2700, 6500));
      case (MiioKind.light || MiioKind.plug, _) when on != null:
        await _client.setProperty(host, token, 2, 1, on);
      default:
        throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} for ${device.model}',
        );
    }
  }
}

SmartHomeDevice parseMiio(
  ConfiguredDevice device, {
  bool on = false,
  int? brightness,
  int? kelvin,
  Map<String, Object?>? vacuum,
}) {
  final kind = miioKind(device.model);
  final name = device.label ?? 'Xiaomi';
  if (kind == MiioKind.vacuum) {
    final raw = roborockState((vacuum?['state'] as num?)?.toInt());
    return SmartHomeDevice(
      id: '${device.key}:vacuum',
      sourceId: device.host,
      deviceId: device.key,
      name: name,
      kind: DeviceKind.vacuum,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'Roborock',
      model: device.model,
      available: true,
      capabilities: const {
        Capability.vacuumStart,
        Capability.vacuumPause,
        Capability.vacuumReturnHome,
      },
      state: DeviceState(raw: raw),
      metadata: DeviceMetadata(
        batteryPercent: (vacuum?['battery'] as num?)?.round(),
      ),
    );
  }
  final light = kind == MiioKind.light;
  return SmartHomeDevice(
    id: '${device.key}:${light ? 'light' : 'switch'}',
    sourceId: device.host,
    deviceId: device.key,
    name: name,
    kind: light ? DeviceKind.dimmableLight : DeviceKind.outlet,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Xiaomi',
    model: device.model,
    available: true,
    capabilities: {
      Capability.power,
      if (light) Capability.brightness,
      if (light && kelvin != null) Capability.colorTemperature,
    },
    state: DeviceState(
      raw: on ? 'on' : 'off',
      isOn: on,
      brightnessPercent: on && light ? brightness : null,
      colorTemperatureKelvin: on && light ? kelvin : null,
    ),
    limits: light && kelvin != null
        ? const DeviceLimits(
            minColorTemperatureKelvin: 2700,
            maxColorTemperatureKelvin: 6500,
          )
        : DeviceLimits.none,
  );
}

/// Xiaomi devices on the network: they answer a broadcast hello with
/// their id.
Future<List<({String host, int id})>> miioDiscover(LanUdp udp) async {
  final answers = await udp.ask(
    '255.255.255.255',
    54321,
    miioHello,
    wait: const Duration(seconds: 3),
    first: false,
  );
  final out = <int, ({String host, int id})>{};
  for (final a in answers) {
    final h = miioHeader(a.data);
    if (h != null && h.id != 0xFFFFFFFF) out[h.id] = (host: a.host, id: h.id);
  }
  return out.values.toList();
}

final miioClientProvider = Provider<MiioClient>(
  (ref) => MiioClient(ref.watch(lanUdpProvider)),
);
