import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'shelly_adapter.dart' show normalizeMac;

/// The "autokey" XOR of the TP-Link Kasa local protocol.
Uint8List kasaEncrypt(String json) {
  var key = 171;
  return Uint8List.fromList([for (final b in utf8.encode(json)) key = key ^ b]);
}

String kasaDecrypt(List<int> data) {
  var key = 171;
  final out = <int>[];
  for (final b in data) {
    out.add(key ^ b);
    key = b;
  }
  return utf8.decode(out, allowMalformed: true);
}

/// A Kasa device that answered the search.
@immutable
class KasaFound {
  const KasaFound({required this.host, required this.sysinfo});

  final String host;
  final Map<String, Object?> sysinfo;
}

/// The older Kasa local protocol: JSON, XOR-"encrypted", on TCP 9999
/// (with a length) and on UDP 9999 for the search. Newer firmware that
/// only speaks the newer, account-bound protocol (KLAP) does not answer.
abstract interface class KasaTransport {
  Future<Map<String, Object?>> send(String host, Map<String, Object?> request);

  Stream<List<KasaFound>> discover();
}

class SocketKasaTransport implements KasaTransport {
  @override
  Future<Map<String, Object?>> send(
    String host,
    Map<String, Object?> request,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        9999,
        timeout: const Duration(seconds: 3),
      );
      final payload = kasaEncrypt(jsonEncode(request));
      socket.add(
        (ByteData(4)..setUint32(0, payload.length)).buffer.asUint8List(),
      );
      socket.add(payload);
      final buffer = BytesBuilder(copy: false);
      int? length;
      await for (final chunk in socket.timeout(const Duration(seconds: 4))) {
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        if (length == null && bytes.length >= 4) {
          length = ByteData.sublistView(bytes, 0, 4).getUint32(0);
        }
        if (length != null && bytes.length >= 4 + length) {
          return _map(jsonDecode(kasaDecrypt(bytes.sublist(4, 4 + length))));
        }
      }
      throw const AppFailure(FailureKind.network, debugMessage: 'kasa');
    } on SocketException {
      throw const AppFailure(FailureKind.network, debugMessage: 'kasa');
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'kasa');
    } on FormatException {
      throw const AppFailure(FailureKind.parsing, debugMessage: 'kasa');
    } finally {
      socket?.destroy();
    }
  }

  @override
  Stream<List<KasaFound>> discover() async* {
    final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        ..broadcastEnabled = true;
    } on SocketException {
      return;
    }
    final found = <String, KasaFound>{};
    final changes = StreamController<List<KasaFound>>();
    final sub = udp.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = udp.receive();
      if (packet == null) return;
      try {
        final sysinfo = _map(
          _map(
            _map(jsonDecode(kasaDecrypt(packet.data)))['system'],
          )['get_sysinfo'],
        );
        if (sysinfo.isEmpty) return;
        found[packet.address.address] = KasaFound(
          host: packet.address.address,
          sysinfo: sysinfo,
        );
        changes.add(List.unmodifiable(found.values));
      } on FormatException {
        // Not a Kasa answer.
      }
    });
    final search = kasaEncrypt(jsonEncode(_sysinfo));
    final everyone = InternetAddress('255.255.255.255');
    final timers = [
      for (var i = 0; i < 3; i++)
        Timer(Duration(seconds: i), () => udp.send(search, everyone, 9999)),
    ];
    unawaited(
      Future<void>.delayed(const Duration(seconds: 4), () async {
        for (final t in timers) {
          t.cancel();
        }
        await sub.cancel();
        udp.close();
        await changes.close();
      }),
    );
    yield* changes.stream;
  }
}

const _sysinfo = {
  'system': {'get_sysinfo': <String, Object?>{}},
};

final kasaTransportProvider = Provider<KasaTransport>(
  (ref) => SocketKasaTransport(),
);

/// The MAC of a device from its `get_sysinfo`.
String? kasaMac(Map<String, Object?> sysinfo) =>
    switch (sysinfo['mac'] ?? sysinfo['mic_mac']) {
      final String mac => normalizeMac(mac),
      _ => null,
    };

/// TP-Link Kasa plugs, switches, dimmers, power strips and bulbs (older
/// local protocol): on/off, brightness, bulbs' colour temperature and
/// colour, and power where the device measures it.
class KasaAdapter extends PolledAdapter {
  KasaAdapter(this._transport, {super.pollEvery});

  final KasaTransport _transport;

  @override
  String get id => 'kasa';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final answer = await _transport.send(device.host, {
      ..._sysinfo,
      'emeter': {'get_realtime': <String, Object?>{}},
    });
    return parseKasa(device, answer);
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last;
    final on = switch (command) {
      TurnOn() => true,
      TurnOff() => false,
      Toggle() => channel.state.isOn != true,
      _ => null,
    };
    final Map<String, Object?> request;
    if (part == 'bulb') {
      const service = 'smartlife.iot.smartbulb.lightingservice';
      final state = <String, Object?>{
        'ignore_default': 1,
        'transition_period': 300,
        ...switch (command) {
          SetBrightness(:final percent) =>
            percent > 0 ? {'on_off': 1, 'brightness': percent} : {'on_off': 0},
          SetColorTemperature(:final kelvin) => {
            'on_off': 1,
            'color_temp': kelvin,
          },
          SetRgbColor(:final color) => {
            'on_off': 1,
            'color_temp': 0,
            ..._hueSaturation(color),
          },
          _ when on != null => {'on_off': on ? 1 : 0},
          _ => _unsupported(command),
        },
      };
      request = {
        service: {'transition_light_state': state},
      };
    } else if (command is SetBrightness) {
      request = command.percent == 0
          ? _relay(part, false)
          : {
              'smartlife.iot.dimmer': {
                'set_brightness': {'brightness': command.percent},
              },
              ..._relay(part, true),
            };
    } else if (on != null) {
      request = _relay(part, on);
    } else {
      _unsupported(command);
    }
    final answer = await _transport.send(device.host, request);
    final error = _firstError(answer);
    if (error != null) {
      throw AppFailure(FailureKind.server, debugMessage: 'kasa: $error');
    }
  }

  /// A relay, or one outlet of a strip (`child2` → its child id).
  Map<String, Object?> _relay(String part, bool on) => {
    if (part.startsWith('child'))
      'context': {
        'child_ids': [part.substring(5)],
      },
    'system': {
      'set_relay_state': {'state': on ? 1 : 0},
    },
  };

  static Never _unsupported(DeviceCommand command) => throw AppFailure(
    FailureKind.unsupportedFeature,
    debugMessage: '${command.runtimeType} for Kasa',
  );
}

/// `err_code` of any part of an answer, if not 0.
Object? _firstError(Map<String, Object?> answer) {
  for (final module in answer.values) {
    for (final method in _map(module).values) {
      final code = _map(method)['err_code'];
      if (code != null && code != 0) return code;
    }
  }
  return null;
}

Map<String, int> _hueSaturation(RgbColor c) {
  final r = c.red / 255, g = c.green / 255, b = c.blue / 255;
  final top = [r, g, b].reduce(max), low = [r, g, b].reduce(min);
  final d = top - low;
  var h = 0.0;
  if (d > 0) {
    h = top == r
        ? ((g - b) / d) % 6
        : top == g
        ? (b - r) / d + 2
        : (r - g) / d + 4;
  }
  return {
    'hue': (h * 60).round() % 360,
    'saturation': top == 0 ? 0 : (d / top * 100).round(),
  };
}

RgbColor _rgbOf(num hue, num saturation) {
  final h = hue / 60, s = saturation / 100;
  final x = s * (1 - (h % 2 - 1).abs());
  final (r, g, b) = switch (h.floor() % 6) {
    0 => (s, x, 0.0),
    1 => (x, s, 0.0),
    2 => (0.0, s, x),
    3 => (0.0, x, s),
    4 => (x, 0.0, s),
    _ => (s, 0.0, x),
  };
  final m = 1 - s;
  int c(double v) => ((v + m) * 255).round().clamp(0, 255);
  return RgbColor(c(r), c(g), c(b));
}

List<SmartHomeDevice> parseKasa(
  ConfiguredDevice device,
  Map<String, Object?> answer,
) {
  final info = _map(_map(answer['system'])['get_sysinfo']);
  final realtime = _map(_map(answer['emeter'])['get_realtime']);
  final alias = info['alias'] as String? ?? device.label ?? 'Kasa';
  final model = info['model'] as String? ?? device.model ?? '';
  final metadata = DeviceMetadata(
    signalStrength: _num(info['rssi']),
    signalUnit: 'dBm',
  );
  SmartHomeDevice make(
    String part,
    String name,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state, {
    DeviceLimits limits = DeviceLimits.none,
  }) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: part,
    deviceId: device.key,
    name: name,
    kind: kind,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'TP-Link',
    model: model,
    available: true,
    capabilities: capabilities,
    state: state,
    limits: limits,
    metadata: metadata,
  );
  final out = <SmartHomeDevice>[];

  final light = _map(info['light_state']);
  if (light.isNotEmpty) {
    // A bulb; when off, its last state is under dft_on_state.
    final on = light['on_off'] == 1;
    final s = on ? light : _map(light['dft_on_state']);
    final color = info['is_color'] == 1;
    final ct = info['is_variable_color_temp'] == 1;
    final temp = _num(s['color_temp']);
    out.add(
      make(
        'bulb',
        alias,
        color ? DeviceKind.rgbLight : DeviceKind.dimmableLight,
        {
          Capability.power,
          if (info['is_dimmable'] != 0) Capability.brightness,
          if (ct) Capability.colorTemperature,
          if (color) Capability.rgb,
        },
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on ? _num(s['brightness'])?.round() : null,
          colorTemperatureKelvin: on && temp != null && temp > 0
              ? temp.round()
              : null,
          rgb: on && color && (temp == null || temp == 0)
              ? _rgbOf(_num(s['hue']) ?? 0, _num(s['saturation']) ?? 0)
              : null,
        ),
        limits: ct
            ? const DeviceLimits(
                minColorTemperatureKelvin: 2500,
                maxColorTemperatureKelvin: 6500,
              )
            : DeviceLimits.none,
      ),
    );
  } else if (info['children'] case final List<Object?> children
      when children.isNotEmpty) {
    for (final (i, c) in children.indexed) {
      final child = _map(c);
      final childId = '${child['id'] ?? i}';
      final on = child['state'] == 1;
      out.add(
        make(
          'child$childId',
          child['alias'] as String? ?? '$alias ${i + 1}',
          DeviceKind.outlet,
          {Capability.power},
          DeviceState(raw: on ? 'on' : 'off', isOn: on),
        ),
      );
    }
  } else if (info.containsKey('relay_state')) {
    final on = info['relay_state'] == 1;
    final brightness = _num(info['brightness'])?.round();
    final dimmer = brightness != null;
    out.add(
      make(
        'relay',
        alias,
        dimmer
            ? DeviceKind.dimmableLight
            : (model.startsWith('HS2')
                  ? DeviceKind.switchDevice
                  : DeviceKind.outlet),
        {Capability.power, if (dimmer) Capability.brightness},
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on && dimmer ? brightness : null,
        ),
      ),
    );
  }

  // power_mw on newer firmware, power (W) on older.
  final power = _num(realtime['power_mw']) != null
      ? _num(realtime['power_mw'])! / 1000
      : _num(realtime['power']);
  if (power != null) {
    out.add(
      make('power', '$alias · W', DeviceKind.powerMeter, {
        Capability.powerConsumption,
      }, DeviceState(raw: '$power', numericValue: power, unit: 'W')),
    );
  }
  return out;
}

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};

double? _num(Object? v) => v is num ? v.toDouble() : null;
