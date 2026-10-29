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
/// brightness and the colour of the main segment.
class WledAdapter extends PolledAdapter {
  WledAdapter(this._http, {super.pollEvery});

  final LanHttp _http;

  /// `/json/info` by [ConfiguredDevice.key], read once.
  final Map<String, Map<String, Object?>> _info = {};

  @override
  String get id => 'wled';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final info = _info[device.key] ??= _map(
      await _http.get(device.host, '/json/info'),
    );
    final state = _map(await _http.get(device.host, '/json/state'));
    return [parseWled(device, info, state)];
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final body = switch (command) {
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

SmartHomeDevice parseWled(
  ConfiguredDevice device,
  Map<String, Object?> info,
  Map<String, Object?> state,
) {
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
  return SmartHomeDevice(
    id: '${device.key}:light',
    sourceId: device.host,
    deviceId: device.key,
    name: info['name'] as String? ?? device.label ?? 'WLED',
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
    metadata: DeviceMetadata(
      signalStrength: switch (_map(info['wifi'])['rssi']) {
        final num r => r.toDouble(),
        _ => null,
      },
      signalUnit: 'dBm',
    ),
  );
}

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};
