import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Govee lights with the "LAN Control" switch on in the Govee app: JSON
/// over UDP. Commands go to port 4003, answers come back to port 4002.
class GoveeAdapter extends PolledAdapter {
  GoveeAdapter(this._udp, {super.pollEvery});

  final LanUdp _udp;

  @override
  String get id => 'govee';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final answers = await _udp.ask(
      device.host,
      4003,
      goveeMessage('devStatus', {}),
      listenPort: 4002,
    );
    for (final a in answers) {
      final data = goveeData(a.text, 'devStatus');
      if (data != null) return [parseGovee(device, data)];
    }
    throw const AppFailure(FailureKind.timeout, debugMessage: 'govee');
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final messages = switch (command) {
      TurnOn() => [
        goveeMessage('turn', {'value': 1}),
      ],
      TurnOff() => [
        goveeMessage('turn', {'value': 0}),
      ],
      Toggle() => [
        goveeMessage('turn', {'value': channel.state.isOn == true ? 0 : 1}),
      ],
      SetBrightness(:final percent) when percent == 0 => [
        goveeMessage('turn', {'value': 0}),
      ],
      SetBrightness(:final percent) => [
        if (channel.state.isOn != true) goveeMessage('turn', {'value': 1}),
        goveeMessage('brightness', {'value': percent.clamp(1, 100)}),
      ],
      SetColorTemperature(:final kelvin) => [
        if (channel.state.isOn != true) goveeMessage('turn', {'value': 1}),
        goveeMessage('colorwc', {
          'color': {'r': 0, 'g': 0, 'b': 0},
          'colorTemInKelvin': kelvin.clamp(2000, 9000),
        }),
      ],
      SetRgbColor(:final color) => [
        if (channel.state.isOn != true) goveeMessage('turn', {'value': 1}),
        goveeMessage('colorwc', {
          'color': {'r': color.red, 'g': color.green, 'b': color.blue},
          'colorTemInKelvin': 0,
        }),
      ],
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Govee',
      ),
    };
    // Commands are not answered.
    for (final m in messages) {
      await _udp.ask(device.host, 4003, m, wait: Duration.zero);
    }
  }
}

List<int> goveeMessage(String cmd, Map<String, Object?> data) => utf8.encode(
  jsonEncode({
    'msg': {'cmd': cmd, 'data': data},
  }),
);

/// The `data` of a [cmd] message; `null` for anything else.
Map<String, Object?>? goveeData(String text, String cmd) {
  try {
    final j = jsonDecode(text);
    final msg = j is Map ? j['msg'] : null;
    if (msg is! Map || msg['cmd'] != cmd || msg['data'] is! Map) return null;
    return (msg['data'] as Map).cast<String, Object?>();
  } on FormatException {
    return null;
  }
}

SmartHomeDevice parseGovee(ConfiguredDevice device, Map<String, Object?> s) {
  final on = s['onOff'] == 1;
  final bright = (s['brightness'] as num?)?.round();
  final kelvin = (s['colorTemInKelvin'] as num?)?.round() ?? 0;
  final c = s['color'];
  final rgb = c is Map && kelvin == 0
      ? RgbColor(
          (c['r'] as num? ?? 0).round(),
          (c['g'] as num? ?? 0).round(),
          (c['b'] as num? ?? 0).round(),
        )
      : null;
  return SmartHomeDevice(
    id: '${device.key}:light',
    sourceId: device.host,
    deviceId: device.key,
    name: device.label ?? 'Govee',
    kind: DeviceKind.rgbLight,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Govee',
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
      brightnessPercent: on ? bright : null,
      colorTemperatureKelvin: on && kelvin > 0 ? kelvin : null,
      rgb: on ? rgb : null,
    ),
    limits: const DeviceLimits(
      minColorTemperatureKelvin: 2000,
      maxColorTemperatureKelvin: 9000,
    ),
  );
}

/// Govee lights on the network: they answer a multicast "scan".
Future<List<({String host, String id, String? sku})>> goveeDiscover(
  LanUdp udp,
) async {
  final answers = await udp.ask(
    '239.255.255.250',
    4001,
    goveeMessage('scan', {'account_topic': 'reserve'}),
    wait: const Duration(seconds: 3),
    first: false,
    listenPort: 4002,
  );
  final out = <String, ({String host, String id, String? sku})>{};
  for (final a in answers) {
    final d = goveeData(a.text, 'scan');
    final id = d?['device'];
    if (d == null || id is! String) continue;
    final key = id.toLowerCase().replaceAll(':', '');
    out[key] = (
      host: d['ip'] as String? ?? a.host,
      id: key,
      sku: d['sku'] as String?,
    );
  }
  return out.values.toList();
}
