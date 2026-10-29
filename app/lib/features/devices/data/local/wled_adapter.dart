import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_http.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'shelly_adapter.dart' show normalizeMac;

/// WLED LED controllers, over their JSON API (`/json/state`): on/off,
/// brightness and the colour of the main segment, and the effect and the
/// preset as choices of their own (`…:effect`, `…:preset`).
class WledAdapter extends PolledAdapter {
  WledAdapter(this._http, {super.pollEvery});

  final LanHttp _http;

  /// `/json/info` by [ConfiguredDevice.key], read once.
  final Map<String, Map<String, Object?>> _info = {};

  /// Effect names (by index) and presets (id → name), read once.
  final Map<String, List<String>> _effects = {};
  final Map<String, Map<int, String>> _presets = {};

  @override
  String get id => 'wled';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final info = _info[device.key] ??= _map(
      await _http.get(device.host, '/json/info'),
    );
    final effects = _effects[device.key] ??= switch (await _quiet(
      device.host,
      '/json/eff',
    )) {
      final List<Object?> names => [for (final n in names) '$n'],
      _ => const <String>[],
    };
    final presets = _presets[device.key] ??= parseWledPresets(
      await _quiet(device.host, '/presets.json'),
    );
    final state = _map(await _http.get(device.host, '/json/state'));
    return parseWled(device, info, state, effects: effects, presets: presets);
  }

  /// Optional parts of the API (older versions, no presets saved).
  Future<Object?> _quiet(String host, String path) async {
    try {
      return await _http.get(host, path);
    } on AppFailure {
      return null;
    }
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last;
    final body = switch (command) {
      SelectOption(:final option) when part == 'effect' => {
        'on': true,
        'seg': [
          {'fx': _effects[device.key]?.indexOf(option) ?? -1},
        ],
      },
      SelectOption(:final option) when part == 'preset' => {
        'ps':
            _presets[device.key]?.entries
                .where((e) => e.value == option)
                .firstOrNull
                ?.key ??
            (throw AppFailure(
              FailureKind.unsupportedFeature,
              debugMessage: 'no WLED preset "$option"',
            )),
      },
      TurnOn() => {'on': true},
      TurnOff() => {'on': false},
      Toggle() => {'on': 't'},
      SetBrightness(:final percent) =>
        percent > 0
            ? {'on': true, 'bri': (percent * 255 / 100).round().clamp(1, 255)}
            : {'on': false},
      SetRgbColor(:final color) => {
        'on': true,
        'seg': [
          {
            'col': [
              [color.red, color.green, color.blue],
            ],
          },
        ],
      },
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for WLED',
      ),
    };
    await _http.post(device.host, '/json/state', body);
  }
}

/// What `GET /json/info` says about a device, if it is a WLED.
typedef WledInfo = ({String mac, String? name, String version});

WledInfo? parseWledInfo(Object? json) {
  final j = _map(json);
  final mac = j['mac'];
  if (j['brand'] != 'WLED' || mac is! String) return null;
  return (
    mac: normalizeMac(mac),
    name: j['name'] as String?,
    version: '${j['ver'] ?? ''}',
  );
}

/// `/presets.json`: `{"1": {"n": "Večer", …}, …}` → id → name (named
/// presets only; `0` is WLED's empty default).
Map<int, String> parseWledPresets(Object? json) {
  final out = <int, String>{};
  for (final MapEntry(:key, :value) in _map(json).entries) {
    final id = int.tryParse(key);
    final name = _map(value)['n'];
    if (id != null && id > 0 && name is String && name.isNotEmpty) {
      out[id] = name;
    }
  }
  return Map.fromEntries(
    out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

List<SmartHomeDevice> parseWled(
  ConfiguredDevice device,
  Map<String, Object?> info,
  Map<String, Object?> state, {
  List<String> effects = const [],
  Map<int, String> presets = const {},
}) {
  final on = state['on'] == true;
  final bri = state['bri'];
  final segments = state['seg'];
  final first = segments is List && segments.isNotEmpty
      ? _map(segments.first)
      : const <String, Object?>{};
  final colors = first['col'];
  final primary = colors is List && colors.isNotEmpty ? colors.first : null;
  final rgb = primary is List && primary.length >= 3
      ? RgbColor(
          (primary[0] as num).round(),
          (primary[1] as num).round(),
          (primary[2] as num).round(),
        )
      : null;
  final name = info['name'] as String? ?? device.label ?? 'WLED';
  final metadata = DeviceMetadata(
    signalStrength: switch (_map(info['wifi'])['rssi']) {
      final num r => r.toDouble(),
      _ => null,
    },
    signalUnit: 'dBm',
  );
  SmartHomeDevice choice(
    String part,
    String label,
    List<String> options,
    String? current,
  ) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: device.host,
    deviceId: device.key,
    name: '$name · $label',
    kind: DeviceKind.select,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'WLED',
    available: true,
    capabilities: const {Capability.selectOption},
    state: DeviceState(raw: current ?? 'unknown', textValue: current),
    limits: DeviceLimits(options: options),
    metadata: metadata,
  );
  final fx = first['fx'];
  final ps = state['ps'];
  return [
    SmartHomeDevice(
      id: '${device.key}:light',
      sourceId: device.host,
      deviceId: device.key,
      name: name,
      kind: DeviceKind.rgbLight,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'WLED',
      model: 'WLED ${info['ver'] ?? ''}'.trim(),
      available: true,
      capabilities: const {
        Capability.power,
        Capability.brightness,
        Capability.rgb,
      },
      state: DeviceState(
        raw: on ? 'on' : 'off',
        isOn: on,
        brightnessPercent: on && bri is num
            ? (bri * 100 / 255).round().clamp(1, 100)
            : null,
        rgb: on ? rgb : null,
      ),
      metadata: metadata,
    ),
    if (effects.isNotEmpty)
      choice(
        'effect',
        'FX',
        effects,
        fx is int && fx >= 0 && fx < effects.length ? effects[fx] : null,
      ),
    if (presets.isNotEmpty)
      choice('preset', 'Preset', presets.values.toList(), presets[ps]),
  ];
}

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};
