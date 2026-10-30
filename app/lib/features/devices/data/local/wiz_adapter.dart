import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Philips WiZ bulbs, strips and plugs: JSON over UDP 38899, no account
/// and no setting needed.
class WizAdapter extends PolledAdapter {
  WizAdapter(this._udp, {super.pollEvery});

  final LanUdp _udp;

  static const port = 38899;

  @override
  String get id => 'wiz';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async => [
    parseWiz(device, await wizCall(_udp, device.host, 'getPilot')),
  ];

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final params = switch (command) {
      TurnOn() => {'state': true},
      TurnOff() => {'state': false},
      Toggle() => {'state': channel.state.isOn != true},
      SetBrightness(:final percent) when percent == 0 => {'state': false},
      // Bulbs take 10–100.
      SetBrightness(:final percent) => {
        'state': true,
        'dimming': percent.clamp(10, 100),
      },
      SetColorTemperature(:final kelvin) => {
        'state': true,
        'temp': kelvin.clamp(2200, 6500),
      },
      SetRgbColor(:final color) => {
        'state': true,
        'r': color.red,
        'g': color.green,
        'b': color.blue,
      },
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for WiZ',
      ),
    };
    await wizCall(_udp, device.host, 'setPilot', params);
  }
}

/// [method]'s `result`; throws `AppFailure` when the device does not
/// answer or refuses.
Future<Map<String, Object?>> wizCall(
  LanUdp udp,
  String host,
  String method, [
  Map<String, Object?> params = const {},
]) async {
  final answers = await udp.ask(
    host,
    WizAdapter.port,
    utf8.encode(jsonEncode({'method': method, 'params': params})),
  );
  final json = answers.isEmpty ? null : _json(answers.first.text);
  final result = json?['result'];
  if (result is! Map) {
    throw AppFailure(
      json == null ? FailureKind.timeout : FailureKind.server,
      debugMessage: 'wiz $method: ${json?['error']}',
    );
  }
  return result.cast<String, Object?>();
}

Map<String, Object?>? _json(String text) {
  try {
    final j = jsonDecode(text);
    return j is Map ? j.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// What a WiZ module is, by its name (`ESP01_SHRGB1C_31`, `ESP10_SOCKET_06`).
({bool plug, bool color, bool white}) wizModule(String? module) {
  final m = (module ?? '').toUpperCase();
  final plug = m.contains('SOCKET');
  final color = !plug && m.contains('RGB');
  final white = !plug && (color || m.contains('TW'));
  return (plug: plug, color: color, white: white);
}

SmartHomeDevice parseWiz(ConfiguredDevice device, Map<String, Object?> pilot) {
  final module = wizModule(device.model);
  final on = pilot['state'] == true;
  final dimming = (pilot['dimming'] as num?)?.round();
  final temp = (pilot['temp'] as num?)?.round();
  final (r, g, b) = (pilot['r'], pilot['g'], pilot['b']);
  // In white mode the bulb reports `temp`; in colour mode `r`, `g`, `b`.
  final rgb = r is num && g is num && b is num && (temp ?? 0) == 0
      ? RgbColor(r.round(), g.round(), b.round())
      : null;
  return SmartHomeDevice(
    id: '${device.key}:${module.plug ? 'switch' : 'light'}',
    sourceId: device.host,
    deviceId: device.key,
    name: device.label ?? 'WiZ',
    kind: module.plug
        ? DeviceKind.outlet
        : module.color
        ? DeviceKind.rgbLight
        : DeviceKind.dimmableLight,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'WiZ',
    model: device.model,
    available: true,
    capabilities: {
      Capability.power,
      if (!module.plug) Capability.brightness,
      if (module.white) Capability.colorTemperature,
      if (module.color) Capability.rgb,
    },
    state: DeviceState(
      raw: on ? 'on' : 'off',
      isOn: on,
      brightnessPercent: on && !module.plug ? dimming : null,
      colorTemperatureKelvin: on && module.white && (temp ?? 0) > 0
          ? temp
          : null,
      rgb: on && module.color ? rgb : null,
    ),
    limits: module.white
        ? const DeviceLimits(
            minColorTemperatureKelvin: 2200,
            maxColorTemperatureKelvin: 6500,
          )
        : DeviceLimits.none,
  );
}

/// A WiZ device that answered: who it is (`getSystemConfig`).
typedef WizFound = ({String host, String mac, String? module});

/// WiZ devices on the network: they answer a broadcast "registration".
Future<List<WizFound>> wizDiscover(LanUdp udp) async {
  final answers = await udp.ask(
    '255.255.255.255',
    WizAdapter.port,
    utf8.encode(
      jsonEncode({
        'method': 'registration',
        'params': {
          'phoneMac': 'AAAAAAAAAAAA',
          'register': false,
          'phoneIp': '1.2.3.4',
          'id': '1',
        },
      }),
    ),
    wait: const Duration(seconds: 3),
    first: false,
  );
  final out = <String, WizFound>{};
  for (final a in answers) {
    if (out.containsKey(a.host)) continue;
    final found = await wizProbe(udp, a.host);
    if (found != null) out[a.host] = found;
  }
  return out.values.toList();
}

/// The WiZ device at [host], or `null`.
Future<WizFound?> wizProbe(LanUdp udp, String host) async {
  try {
    final c = await wizCall(udp, host, 'getSystemConfig');
    final mac = c['mac'];
    if (mac is! String || mac.isEmpty) return null;
    return (
      host: host,
      mac: mac.toLowerCase().replaceAll(':', ''),
      module: c['moduleName'] as String?,
    );
  } on AppFailure {
    return null;
  }
}
