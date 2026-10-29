import 'dart:math';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_http.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'shelly_adapter.dart' show normalizeMac;

/// Philips Hue lights and sensors through the Hue bridge's local API (v1):
/// on/off, brightness, colour temperature and colour; temperature and
/// motion sensors. The bridge is paired once with its button
/// ([hueLink]); the app's user name it gives is kept like a password.
///
/// The bridge brings its Zigbee lights with it, so each light is a device
/// of its own (`hue:<bridge>:light3`).
class HueAdapter extends PolledAdapter {
  HueAdapter(this._http, {this.users, super.pollEvery});

  final LanHttp _http;

  /// The app's user name on a bridge, by [ConfiguredDevice.key].
  final Future<String?> Function(String key)? users;
  final Map<String, String?> _users = {};

  @override
  String get id => 'hue';

  @override
  void configure(List<ConfiguredDevice> devices) {
    _users.clear();
    super.configure(devices);
  }

  Future<String> _user(ConfiguredDevice device) async {
    final user = _users[device.key] ??= await users?.call(device.key);
    if (user == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'hue: not paired',
      );
    }
    return user;
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final user = await _user(device);
    final (lights, sensors) = await (
      _http.get(device.host, '/api/$user/lights'),
      _http.get(device.host, '/api/$user/sensors'),
    ).wait;
    _checkError(lights);
    return parseHue(device, _map(lights), _map(sensors));
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last;
    if (!part.startsWith('light')) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for ${channel.id}',
      );
    }
    final body = switch (command) {
      TurnOn() => {'on': true},
      TurnOff() => {'on': false},
      Toggle() => {'on': channel.state.isOn != true},
      SetBrightness(:final percent) =>
        percent > 0
            ? {'on': true, 'bri': (percent * 254 / 100).round().clamp(1, 254)}
            : {'on': false},
      SetColorTemperature(:final kelvin) => {
        'on': true,
        'ct': (1e6 / kelvin).round().clamp(153, 500),
      },
      SetRgbColor(:final color) => {'on': true, 'xy': rgbToXy(color)},
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Hue',
      ),
    };
    final user = await _user(device);
    _checkError(
      await _http.put(
        device.host,
        '/api/$user/lights/${part.substring(5)}/state',
        body,
      ),
    );
  }
}

/// Pairs with the bridge at [host]: answers the app's user name once the
/// bridge's button was pressed, `null` while it was not.
Future<String?> hueLink(LanHttp http, String host) async {
  final answer = await http.post(host, '/api', {
    'devicetype': 'open_smart_home_lite#phone',
  });
  if (answer is List && answer.isNotEmpty) {
    final first = _map(answer.first);
    final user = _map(first['success'])['username'];
    if (user is String) return user;
  }
  return null;
}

/// What `GET /api/config` (no pairing needed) says, if it is a Hue bridge.
typedef HueInfo = ({String id, String name, String model});

HueInfo? parseHueInfo(Object? json) {
  final j = _map(json);
  final bridge = j['bridgeid'];
  final model = j['modelid'];
  if (bridge is! String || model is! String || !model.startsWith('BSB')) {
    return null;
  }
  return (
    id: normalizeMac(bridge),
    name: j['name'] as String? ?? 'Hue',
    model: model,
  );
}

/// The bridge answers errors as a list with HTTP 200.
void _checkError(Object? answer) {
  if (answer is! List) return;
  for (final item in answer) {
    final error = _map(_map(item)['error']);
    if (error.isEmpty) continue;
    throw AppFailure(
      error['type'] == 1 ? FailureKind.authentication : FailureKind.server,
      debugMessage: 'hue error ${error['type']}',
    );
  }
}

List<SmartHomeDevice> parseHue(
  ConfiguredDevice bridge,
  Map<String, Object?> lights,
  Map<String, Object?> sensors,
) {
  final out = <SmartHomeDevice>[];
  SmartHomeDevice make(
    String part,
    Map<String, Object?> json,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state, {
    DeviceLimits limits = DeviceLimits.none,
    bool available = true,
  }) {
    final unique = json['uniqueid'] as String? ?? part;
    final battery = _num(_map(json['config'])['battery'])?.round();
    return SmartHomeDevice(
      id: '${bridge.key}:$part',
      sourceId: part,
      // The physical device: a motion sensor's three sensors together.
      deviceId: '${bridge.key}:${normalizeMac(unique.split('-').first)}',
      name: json['name'] as String? ?? part,
      kind: kind,
      protocol: DeviceProtocol.zigbee,
      manufacturer: json['manufacturername'] as String? ?? 'Philips Hue',
      model: json['modelid'] as String?,
      available: available,
      capabilities: capabilities,
      state: state,
      limits: limits,
      metadata: DeviceMetadata(batteryPercent: battery),
    );
  }

  for (final MapEntry(key: id, :value) in lights.entries) {
    final light = _map(value);
    final s = _map(light['state']);
    final type = '${light['type'] ?? ''}'.toLowerCase();
    final on = s['on'] == true;
    final color = type.contains('color light');
    final ct = _map(_map(_map(light['capabilities'])['control'])['ct']);
    final hasCt = s.containsKey('ct');
    final dimmable = s.containsKey('bri');
    final bri = _num(s['bri']);
    final xy = s['xy'];
    final mireds = _num(s['ct']);
    out.add(
      make(
        'light$id',
        light,
        type.contains('plug')
            ? DeviceKind.outlet
            : color
            ? DeviceKind.rgbLight
            : dimmable
            ? DeviceKind.dimmableLight
            : DeviceKind.light,
        {
          Capability.power,
          if (dimmable) Capability.brightness,
          if (hasCt) Capability.colorTemperature,
          if (color) Capability.rgb,
        },
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on && bri != null
              ? (bri * 100 / 254).round().clamp(1, 100)
              : null,
          colorTemperatureKelvin:
              on && s['colormode'] == 'ct' && mireds != null && mireds > 0
              ? (1e6 / mireds).round()
              : null,
          rgb: on && color && s['colormode'] != 'ct' && xy is List
              ? xyToRgb((xy[0] as num).toDouble(), (xy[1] as num).toDouble())
              : null,
        ),
        limits: hasCt
            ? DeviceLimits(
                minColorTemperatureKelvin: (1e6 / (_num(ct['max']) ?? 500))
                    .round(),
                maxColorTemperatureKelvin: (1e6 / (_num(ct['min']) ?? 153))
                    .round(),
              )
            : DeviceLimits.none,
        available: s['reachable'] != false,
      ),
    );
  }

  for (final MapEntry(key: id, :value) in sensors.entries) {
    final sensor = _map(value);
    final s = _map(sensor['state']);
    final reachable = _map(sensor['config'])['reachable'] != false;
    switch (sensor['type']) {
      case 'ZLLTemperature':
        final t = _num(s['temperature']);
        final c = t == null ? null : t / 100;
        out.add(
          make(
            'sensor$id',
            sensor,
            DeviceKind.temperatureSensor,
            {Capability.currentTemperature},
            DeviceState(
              raw: '$c',
              numericValue: c,
              currentTemperature: c,
              unit: '°C',
            ),
            available: reachable,
          ),
        );
      case 'ZLLPresence':
        final presence = s['presence'] as bool?;
        out.add(
          make(
            'sensor$id',
            sensor,
            DeviceKind.motionSensor,
            const {},
            DeviceState(
              raw: presence == true ? 'on' : 'off',
              isActive: presence,
            ),
            available: reachable,
          ),
        );
    }
  }
  return out;
}

/// sRGB → CIE xy, after Philips' "RGB to xy" (wide gamut, D65).
List<double> rgbToXy(RgbColor c) {
  double lin(int v) {
    final x = v / 255;
    return x > 0.04045 ? pow((x + 0.055) / 1.055, 2.4).toDouble() : x / 12.92;
  }

  final (r, g, b) = (lin(c.red), lin(c.green), lin(c.blue));
  final x = r * 0.664511 + g * 0.154324 + b * 0.162028;
  final y = r * 0.283881 + g * 0.668433 + b * 0.047685;
  final z = r * 0.000088 + g * 0.072310 + b * 0.986039;
  final sum = x + y + z;
  if (sum == 0) return [0.3227, 0.329];
  double round(double v) => (v * 10000).round() / 10000;
  return [round(x / sum), round(y / sum)];
}

/// CIE xy → sRGB at full brightness (the reverse of [rgbToXy]).
RgbColor xyToRgb(double x, double y) {
  if (y <= 0) return const RgbColor(255, 255, 255);
  final z = 1 - x - y;
  final bigX = x / y;
  final bigZ = z / y;
  var r = bigX * 1.656492 - 0.354851 - bigZ * 0.255038;
  var g = -bigX * 0.707196 + 1.655397 + bigZ * 0.036152;
  var b = bigX * 0.051713 - 0.121364 + bigZ * 1.011530;
  final top = [r, g, b].reduce(max);
  if (top > 1) {
    r /= top;
    g /= top;
    b /= top;
  }
  int gamma(double v) {
    final c = v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055;
    return (c.clamp(0, 1) * 255).round();
  }

  return RgbColor(gamma(r), gamma(g), gamma(b));
}

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};

double? _num(Object? v) => v is num ? v.toDouble() : null;
