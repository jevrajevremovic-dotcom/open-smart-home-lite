import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// A Yeelight bulb or strip that answered the search.
@immutable
class YeelightFound {
  const YeelightFound({
    required this.id,
    required this.host,
    required this.model,
    this.name = '',
  });

  /// `0x000000000015243f` → `000000000015243f`.
  final String id;
  final String host;
  final String model;
  final String name;
}

/// The Yeelight LAN protocol: a search on UDP 1982 (SSDP-like) and one
/// JSON command per line on TCP 55443. Needs "LAN Control" on in the
/// Yeelight app.
abstract interface class YeelightTransport {
  /// The `result` of [method]; throws `AppFailure`.
  Future<List<Object?>> call(String host, String method, List<Object?> params);

  /// Bulbs answering a search for a few seconds.
  Stream<List<YeelightFound>> discover();
}

class SocketYeelightTransport implements YeelightTransport {
  int _id = 0;

  @override
  Future<List<Object?>> call(
    String host,
    String method,
    List<Object?> params,
  ) async {
    final id = ++_id;
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        55443,
        timeout: const Duration(seconds: 3),
      );
      socket.write(
        '${jsonEncode({'id': id, 'method': method, 'params': params})}\r\n',
      );
      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines.timeout(const Duration(seconds: 4))) {
        final Object? json;
        try {
          json = jsonDecode(line);
        } on FormatException {
          continue;
        }
        // Notifications ("props") come too; only our answer counts.
        if (json is! Map || json['id'] != id) continue;
        if (json['error'] case final Map<Object?, Object?> error) {
          throw AppFailure(
            FailureKind.server,
            debugMessage: 'yeelight: ${error['message']}',
          );
        }
        final result = json['result'];
        return result is List ? result : const [];
      }
      throw const AppFailure(FailureKind.network, debugMessage: 'no answer');
    } on SocketException {
      throw const AppFailure(FailureKind.network, debugMessage: 'yeelight');
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout, debugMessage: 'yeelight');
    } finally {
      socket?.destroy();
    }
  }

  @override
  Stream<List<YeelightFound>> discover() async* {
    final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      return;
    }
    final found = <String, YeelightFound>{};
    final changes = StreamController<List<YeelightFound>>();
    final search = ascii.encode(
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1982\r\n'
      'MAN: "ssdp:discover"\r\n'
      'ST: wifi_bulb\r\n',
    );
    final sub = udp.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = udp.receive();
      if (packet == null) return;
      final bulb = parseYeelightAnswer(
        utf8.decode(packet.data, allowMalformed: true),
      );
      if (bulb != null && found[bulb.id]?.host != bulb.host) {
        found[bulb.id] = bulb;
        changes.add(List.unmodifiable(found.values));
      }
    });
    // UDP may be lost: asked three times, a second apart.
    final multicast = InternetAddress('239.255.255.250');
    final timers = [
      for (var i = 0; i < 3; i++)
        Timer(Duration(seconds: i), () => udp.send(search, multicast, 1982)),
    ];
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), () async {
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

/// A search answer (`HTTP/1.1 200 OK … Location: yeelight://ip:55443`).
YeelightFound? parseYeelightAnswer(String text) {
  final headers = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    final colon = line.indexOf(':');
    if (colon > 0) {
      headers[line.substring(0, colon).trim().toLowerCase()] = line
          .substring(colon + 1)
          .trim();
    }
  }
  final location = Uri.tryParse(headers['location'] ?? '');
  final id = headers['id'];
  if (location == null || location.scheme != 'yeelight' || id == null) {
    return null;
  }
  return YeelightFound(
    id: id.toLowerCase().replaceFirst('0x', ''),
    host: location.host,
    model: headers['model'] ?? 'yeelight',
    name: headers['name'] ?? '',
  );
}

final yeelightTransportProvider = Provider<YeelightTransport>(
  (ref) => SocketYeelightTransport(),
);

/// Yeelight bulbs, light strips and ceiling lights: on/off, brightness,
/// colour temperature and (colour models) colour. Asked every 10 s — the
/// bulbs allow only so many commands a minute.
class YeelightAdapter extends PolledAdapter {
  YeelightAdapter(
    this._transport, {
    super.pollEvery = const Duration(seconds: 10),
  });

  final YeelightTransport _transport;

  static const _props = ['power', 'bright', 'ct', 'rgb', 'color_mode', 'name'];

  @override
  String get id => 'yeelight';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async => [
    parseYeelight(
      device,
      await _transport.call(device.host, 'get_prop', _props),
    ),
  ];

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    const smooth = ['smooth', 300];
    final (method, params) = switch (command) {
      TurnOn() => ('set_power', ['on', ...smooth]),
      TurnOff() => ('set_power', ['off', ...smooth]),
      Toggle() => ('toggle', const <Object?>[]),
      SetBrightness(:final percent) when percent == 0 => (
        'set_power',
        ['off', ...smooth],
      ),
      SetBrightness(:final percent) => ('set_bright', [percent, ...smooth]),
      SetColorTemperature(:final kelvin) => (
        'set_ct_abx',
        [kelvin.clamp(1700, 6500), ...smooth],
      ),
      SetRgbColor(:final color) => (
        'set_rgb',
        [color.red << 16 | color.green << 8 | color.blue, ...smooth],
      ),
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Yeelight',
      ),
    };
    // A bulb that is off takes the colour only once on.
    if (command is SetColorTemperature || command is SetRgbColor) {
      if (channel.state.isOn != true) {
        await _transport.call(device.host, 'set_power', ['on', ...smooth]);
      }
    }
    await _transport.call(device.host, method, params);
  }
}

SmartHomeDevice parseYeelight(ConfiguredDevice device, List<Object?> props) {
  String prop(int i) => i < props.length ? '${props[i]}' : '';
  final model = (device.model ?? '').toLowerCase();
  final mono = model.contains('mono');
  final color = !mono && !model.contains('ceiling') && !model.contains('ct');
  final on = prop(0) == 'on';
  final bright = int.tryParse(prop(1));
  final ct = int.tryParse(prop(2));
  final rgb = int.tryParse(prop(3));
  final mode = prop(4); // 1 rgb, 2 ct, 3 hsv
  final name = prop(5);
  return SmartHomeDevice(
    id: '${device.key}:light',
    sourceId: device.host,
    deviceId: device.key,
    name: name.isNotEmpty ? name : (device.label ?? 'Yeelight'),
    kind: color ? DeviceKind.rgbLight : DeviceKind.dimmableLight,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Yeelight',
    model: device.model,
    available: true,
    capabilities: {
      Capability.power,
      Capability.brightness,
      if (!mono) Capability.colorTemperature,
      if (color) Capability.rgb,
    },
    state: DeviceState(
      raw: on ? 'on' : 'off',
      isOn: on,
      brightnessPercent: on ? bright : null,
      colorTemperatureKelvin: on && !mono && mode == '2' ? ct : null,
      rgb: on && color && mode == '1' && rgb != null
          ? RgbColor(rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF)
          : null,
    ),
    limits: mono
        ? DeviceLimits.none
        : const DeviceLimits(
            minColorTemperatureKelvin: 1700,
            maxColorTemperatureKelvin: 6500,
          ),
  );
}
