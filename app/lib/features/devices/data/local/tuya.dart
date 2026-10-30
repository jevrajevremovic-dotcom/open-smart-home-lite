import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'aes.dart';
import 'color_math.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

// Tuya's local protocol (Smart Life, Tuya Smart and the many brands on
// them), versions 3.3 and 3.4, TCP port 6668. Every device has a "local
// key" (16 characters) the person takes once from their Tuya account
// (e.g. with tinytuya's wizard); with it the phone talks to the device
// directly. 3.5 is not spoken yet.

const tuyaControl = 7;
const tuyaStatus = 8;
const tuyaDpQuery = 10;
const tuyaControlNew = 13;
const tuyaDpQueryNew = 16;
const tuyaSessionStart = 3;
const tuyaSessionResponse = 4;
const tuyaSessionFinish = 5;

/// A frame: prefix, sequence, command, length, payload, CRC32 (3.3) or
/// HMAC-SHA256 with [hmacKey] (3.4), suffix.
Uint8List tuyaFrame(int seq, int cmd, List<int> payload, {List<int>? hmacKey}) {
  final tail = (hmacKey == null ? 4 : 32) + 4;
  final head = ByteData(16)
    ..setUint32(0, 0x000055AA)
    ..setUint32(4, seq)
    ..setUint32(8, cmd)
    ..setUint32(12, payload.length + tail);
  final body = [...head.buffer.asUint8List(), ...payload];
  final check = hmacKey == null
      ? (ByteData(4)..setUint32(0, crc32(body))).buffer.asUint8List()
      : hash.Hmac(hash.sha256, hmacKey).convert(body).bytes;
  return Uint8List.fromList([...body, ...check, 0, 0, 0xAA, 0x99]);
}

/// The frames in [data] (several may come in one read): command and
/// payload (as sent: a device's starts with a 4-byte return code).
List<({int cmd, Uint8List payload})> tuyaFrames(
  Uint8List data, {
  bool hmac = false,
}) {
  final out = <({int cmd, Uint8List payload})>[];
  final tail = (hmac ? 32 : 4) + 4;
  var i = 0;
  while (i + 16 <= data.length) {
    final b = ByteData.sublistView(data, i);
    if (b.getUint32(0) != 0x000055AA) {
      i++;
      continue;
    }
    final len = b.getUint32(12);
    if (i + 16 + len > data.length || len < tail) break;
    out.add((
      cmd: b.getUint32(8),
      payload: Uint8List.sublistView(data, i + 16, i + 16 + len - tail),
    ));
    i += 16 + len;
  }
  return out;
}

/// The JSON a device sent in [payload], with or without its return code
/// and version header; `null` when it is not readable with [key].
Map<String, Object?>? tuyaOpen(List<int> payload, List<int> key) {
  Uint8List strip(Uint8List p) =>
      p.length >= 15 && p[0] == 0x33 && p[1] == 0x2E ? p.sublist(15) : p;
  for (final start in const [0, 4]) {
    if (payload.length <= start) continue;
    final p = strip(Uint8List.fromList(payload.sublist(start)));
    var clear = p;
    if (p.isNotEmpty && p.length % 16 == 0) {
      try {
        clear = strip(aesEcbDecrypt(key, p));
      } on FormatException {
        continue;
      }
    }
    try {
      final j = jsonDecode(utf8.decode(clear));
      if (j is Map) return j.cast<String, Object?>();
    } on FormatException {
      // Not this way.
    }
  }
  return null;
}

int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// One conversation with a Tuya device: (3.4: a session key first) then
/// one request and its answer.
class TuyaClient {
  TuyaClient(this._tcp);

  final LanTcp _tcp;
  final _random = Random.secure();

  /// The device's data points (`{"1": true, "19": 1234}`).
  Future<Map<String, Object?>> status(TuyaTarget t) async {
    final ts = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final answer = await _converse(
      t,
      t.v34 ? tuyaDpQueryNew : tuyaDpQuery,
      t.v34
          ? <String, Object?>{}
          : {'gwId': t.id, 'devId': t.id, 'uid': t.id, 't': ts},
      withHeader: false,
    );
    final dps = answer?['dps'] ?? (answer?['data'] as Map?)?['dps'];
    if (dps is! Map) {
      throw const AppFailure(FailureKind.parsing, debugMessage: 'tuya status');
    }
    return dps.cast<String, Object?>();
  }

  Future<void> set(TuyaTarget t, Map<String, Object?> dps) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _converse(
      t,
      t.v34 ? tuyaControlNew : tuyaControl,
      t.v34
          ? {
              'protocol': 5,
              't': ts,
              'data': {'dps': dps},
            }
          : {'devId': t.id, 'uid': t.id, 't': '$ts', 'dps': dps},
      withHeader: true,
      wantDps: false,
    );
  }

  Future<Map<String, Object?>?> _converse(
    TuyaTarget t,
    int cmd,
    Map<String, Object?> json, {
    required bool withHeader,
    bool wantDps = true,
  }) async {
    final link = await _tcp.connect(t.host, 6668);
    final frames = StreamController<({int cmd, Uint8List payload})>();
    final sub = link.data.listen(
      (d) => tuyaFrames(d, hmac: t.v34).forEach(frames.add),
      onError: frames.addError,
      onDone: frames.close,
    );
    final queue = StreamIterator(frames.stream);
    Future<({int cmd, Uint8List payload})> next() async {
      if (!await queue.moveNext().timeout(const Duration(seconds: 5))) {
        throw const AppFailure(
          FailureKind.network,
          debugMessage: 'tuya closed',
        );
      }
      return queue.current;
    }

    try {
      var seq = 1;
      var key = t.key;
      if (t.v34) {
        final local = [for (var i = 0; i < 16; i++) _random.nextInt(26) + 0x61];
        link.add(
          tuyaFrame(
            seq++,
            tuyaSessionStart,
            aesEcbEncrypt(t.key, local),
            hmacKey: t.key,
          ),
        );
        final r = await next();
        final remote = _sessionAnswer(r.payload, t.key);
        if (remote == null) {
          throw const AppFailure(
            FailureKind.authentication,
            debugMessage: 'tuya: wrong local key',
          );
        }
        link.add(
          tuyaFrame(
            seq++,
            tuyaSessionFinish,
            aesEcbEncrypt(
              t.key,
              hash.Hmac(hash.sha256, t.key).convert(remote).bytes,
            ),
            hmacKey: t.key,
          ),
        );
        key = aesEcbEncrypt(t.key, [
          for (var i = 0; i < 16; i++) local[i] ^ remote[i],
        ], pad: false);
      }
      final text = utf8.encode(jsonEncode(json));
      final header = [...ascii.encode(t.version), ...List.filled(12, 0)];
      final payload = t.v34
          ? aesEcbEncrypt(key, [if (withHeader) ...header, ...text])
          : [if (withHeader) ...header, ...aesEcbEncrypt(key, text)];
      link.add(tuyaFrame(seq, cmd, payload, hmacKey: t.v34 ? key : null));
      if (!wantDps) {
        await next(); // the device's acknowledgement
        return null;
      }
      for (var i = 0; i < 4; i++) {
        final r = await next();
        final opened = tuyaOpen(r.payload, key);
        if (opened != null && (opened['dps'] ?? opened['data']) != null) {
          return opened;
        }
      }
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'tuya: unreadable answer (wrong local key?)',
      );
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'tuya');
    } finally {
      await queue.cancel();
      await sub.cancel();
      await link.close();
    }
  }

  /// The device's nonce from its answer to the session start; `null` when
  /// the local key is wrong.
  static List<int>? _sessionAnswer(Uint8List payload, List<int> key) {
    for (final start in const [4, 0]) {
      if (payload.length <= start) continue;
      final p = payload.sublist(start);
      if (p.length % 16 != 0) continue;
      try {
        final clear = aesEcbDecrypt(key, p);
        if (clear.length >= 48) return clear.sublist(0, 16);
      } on FormatException {
        // Try the other way.
      }
    }
    return null;
  }
}

/// A Tuya device as talked to: id (`gwId`), address, local key, version.
class TuyaTarget {
  TuyaTarget(this.id, this.host, String localKey, this.version)
    : key = utf8.encode(localKey);

  final String id;
  final String host;
  final List<int> key;
  final String version;

  bool get v34 => version == '3.4';
}

/// Plugs, switches (one or more channels, power where measured) and
/// lights (the usual "20…24" data points) on Tuya's local protocol.
class TuyaAdapter extends PolledAdapter {
  TuyaAdapter(
    this._client, {
    this.keys,
    super.pollEvery = const Duration(seconds: 10),
  });

  final TuyaClient _client;
  final Future<String?> Function(String key)? keys;

  @override
  String get id => 'tuya';

  Future<TuyaTarget> _target(ConfiguredDevice d) async {
    final key = await keys?.call(d.key);
    if (key == null || key.length != 16) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'tuya: no local key',
      );
    }
    final version = d.options['version'] ?? '3.3';
    if (version != '3.3' && version != '3.4') {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: 'tuya $version',
      );
    }
    return TuyaTarget(d.id, d.host, key, version);
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async =>
      parseTuya(device, await _client.status(await _target(device)));

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last;
    final on = channel.state.isOn == true;
    final Map<String, Object?> dps;
    if (part == 'light') {
      dps = switch (command) {
        TurnOn() => {'20': true},
        TurnOff() => {'20': false},
        Toggle() => {'20': !on},
        SetBrightness(:final percent) when percent == 0 => {'20': false},
        SetBrightness(:final percent) => {
          '20': true,
          '21': 'white',
          '22': (10 + percent * 9.9).round().clamp(10, 1000),
        },
        SetColorTemperature(:final kelvin) => {
          '20': true,
          '21': 'white',
          '23': ((kelvin - 2700) / (6500 - 2700) * 1000).round().clamp(0, 1000),
        },
        SetRgbColor(:final color) => {
          '20': true,
          '21': 'colour',
          '24': tuyaColour(color, channel.state.brightnessPercent ?? 100),
        },
        _ => _unsupported(command),
      };
    } else {
      final dp = part.replaceFirst('switch', '');
      dps = switch (command) {
        TurnOn() => {dp: true},
        TurnOff() => {dp: false},
        Toggle() => {dp: !on},
        _ => _unsupported(command),
      };
    }
    await _client.set(await _target(device), dps);
  }

  static Never _unsupported(DeviceCommand c) => throw AppFailure(
    FailureKind.unsupportedFeature,
    debugMessage: '${c.runtimeType} for Tuya',
  );
}

/// Tuya's colour: hue, saturation and value as 4-digit hex each
/// (`hhhhssssvvvv`, saturation and value 0–1000).
String tuyaColour(RgbColor c, int brightnessPercent) {
  final hsv = rgbToHsv(c);
  String h4(int v) => v.toRadixString(16).padLeft(4, '0');
  return h4(hsv.hue.round()) +
      h4((hsv.saturation * 1000).round()) +
      h4((brightnessPercent * 10).clamp(10, 1000));
}

List<SmartHomeDevice> parseTuya(
  ConfiguredDevice device,
  Map<String, Object?> dps,
) {
  final name = device.label ?? 'Tuya';
  SmartHomeDevice make(
    String part,
    String label,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state, {
    DeviceLimits limits = DeviceLimits.none,
    bool auxiliary = false,
  }) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: device.host,
    deviceId: device.key,
    name: label,
    kind: kind,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Tuya',
    model: device.model,
    available: true,
    capabilities: capabilities,
    state: state,
    limits: limits,
    isAuxiliary: auxiliary,
  );
  // A light: switch_led on 20 (on plugs, 20 is the voltage, a number).
  if (dps['20'] is bool) {
    final on = dps['20'] == true;
    final mode = dps['21'];
    final bright = dps['22'] as num?;
    final temp = dps['23'] as num?;
    final colour = dps['24'];
    RgbColor? rgb;
    if (colour is String && colour.length == 12 && mode == 'colour') {
      final h = int.tryParse(colour.substring(0, 4), radix: 16);
      final s = int.tryParse(colour.substring(4, 8), radix: 16);
      if (h != null && s != null) rgb = hsvToRgb(h.toDouble(), s / 1000);
    }
    return [
      make(
        'light',
        name,
        dps.containsKey('24') ? DeviceKind.rgbLight : DeviceKind.dimmableLight,
        {
          Capability.power,
          if (bright != null) Capability.brightness,
          if (temp != null) Capability.colorTemperature,
          if (dps.containsKey('24')) Capability.rgb,
        },
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on && bright != null
              ? ((bright - 10) / 9.9).round().clamp(1, 100)
              : null,
          colorTemperatureKelvin: on && temp != null && mode != 'colour'
              ? (2700 + temp / 1000 * (6500 - 2700)).round()
              : null,
          rgb: on ? rgb : null,
        ),
        limits: temp != null
            ? const DeviceLimits(
                minColorTemperatureKelvin: 2700,
                maxColorTemperatureKelvin: 6500,
              )
            : DeviceLimits.none,
      ),
    ];
  }
  // Switches: the boolean points 1…9 are the channels.
  final channels = [
    for (var i = 1; i <= 9; i++)
      if (dps['$i'] is bool) '$i',
  ];
  final out = <SmartHomeDevice>[
    for (final dp in channels)
      make(
        'switch$dp',
        channels.length == 1 ? name : '$name $dp',
        DeviceKind.outlet,
        const {Capability.power},
        DeviceState(raw: dps[dp] == true ? 'on' : 'off', isOn: dps[dp] == true),
      ),
  ];
  // cur_power, tenths of a watt, on plugs that measure.
  if (dps['19'] case final num p when channels.isNotEmpty) {
    out.add(
      make(
        'power',
        '$name · W',
        DeviceKind.powerMeter,
        const {Capability.powerConsumption},
        DeviceState(raw: '${p / 10}', numericValue: p / 10, unit: 'W'),
        auxiliary: true,
      ),
    );
  }
  return out;
}

/// The key devices encrypt their 6667 broadcasts with: MD5 of a string
/// fixed in every Tuya firmware.
final _broadcastKey = hash.md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes;

/// What a broadcast says: `{"ip", "gwId", "productKey", "version"…}`.
Map<String, Object?>? tuyaBroadcast(Uint8List data) {
  for (final f in tuyaFrames(data)) {
    final j = tuyaOpen(f.payload, _broadcastKey);
    if (j != null && j['gwId'] is String) return j;
  }
  return null;
}

/// Tuya devices announcing themselves (every few seconds, on UDP 6666 and
/// 6667) while listened to.
Future<List<({String id, String host, String version, String? product})>>
tuyaDiscover(LanUdp udp, {Duration listen = const Duration(seconds: 6)}) async {
  final out =
      <String, ({String id, String host, String version, String? product})>{};
  await Future.wait([
    for (final port in const [6666, 6667])
      udp.listen(port, duration: listen).forEach((p) {
        final j = tuyaBroadcast(p.data);
        if (j == null) return;
        out[j['gwId'] as String] = (
          id: j['gwId'] as String,
          host: j['ip'] as String? ?? p.host,
          version: j['version'] as String? ?? '3.3',
          product: j['productKey'] as String?,
        );
      }),
  ]);
  return out.values.toList();
}

final tuyaClientProvider = Provider<TuyaClient>(
  (ref) => TuyaClient(ref.watch(lanTcpProvider)),
);
