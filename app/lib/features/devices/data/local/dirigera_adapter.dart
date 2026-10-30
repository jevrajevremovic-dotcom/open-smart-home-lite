import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'color_math.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// The IKEA DIRIGERA hub and its Zigbee devices (bulbs, plugs, blinds,
/// motion, door and air sensors) over its local API (HTTPS, port 8443,
/// the hub's own certificate). Paired with the hub's action button
/// ([DirigeraPairing]); the token is kept like a password. Each device of
/// the hub is a device of its own (`dirigera:<hub>:<id>:light`).
class DirigeraAdapter extends PolledAdapter {
  DirigeraAdapter(this._http, {this.tokens, super.pollEvery});

  final LanRequests _http;
  final Future<String?> Function(String key)? tokens;
  final Map<String, String?> _tokens = {};

  @override
  String get id => 'dirigera';

  @override
  void configure(List<ConfiguredDevice> devices) {
    _tokens.clear();
    super.configure(devices);
  }

  Future<Map<String, String>> _auth(ConfiguredDevice hub) async {
    final token = _tokens[hub.key] ??= await tokens?.call(hub.key);
    if (token == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'dirigera: not paired',
      );
    }
    return {'authorization': 'Bearer $token'};
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final r = await _http.send(
      'GET',
      Uri.parse('https://${device.host}:8443/v1/devices'),
      headers: await _auth(device),
      insecure: true,
      pin: device.options['cert'],
    );
    final json = r.json;
    if (!r.ok || json is! List) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'dirigera ${r.status}',
      );
    }
    return parseDirigera(device, json);
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    // `dirigera:<hub>:<id>:light` → `<id>`.
    final parts = channel.id.split(':');
    final target = parts[parts.length - 2];
    final Map<String, Object?> attributes = switch (command) {
      TurnOn() => {'isOn': true},
      TurnOff() => {'isOn': false},
      Toggle() => {'isOn': channel.state.isOn != true},
      SetBrightness(:final percent) when percent == 0 => {'isOn': false},
      SetBrightness(:final percent) => {'lightLevel': percent.clamp(1, 100)},
      SetColorTemperature(:final kelvin) => {'colorTemperature': kelvin},
      SetRgbColor(:final color) => () {
        final hsv = rgbToHsv(color);
        return <String, Object?>{
          'colorHue': hsv.hue.round(),
          'colorSaturation': double.parse(hsv.saturation.toStringAsFixed(2)),
        };
      }(),
      // The hub's level is how far down the blind is; ours how far open.
      OpenCover() => {'blindsTargetLevel': 0},
      CloseCover() => {'blindsTargetLevel': 100},
      SetCoverPosition(:final percent) => {'blindsTargetLevel': 100 - percent},
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for DIRIGERA',
      ),
    };
    final b = jsonBody([
      {'attributes': attributes},
    ]);
    final r = await _http.send(
      'PATCH',
      Uri.parse('https://${device.host}:8443/v1/devices/$target'),
      headers: {...await _auth(device), ...b.headers},
      body: b.body,
      insecure: true,
      pin: device.options['cert'],
    );
    if (!r.ok) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'dirigera ${r.status}',
      );
    }
  }
}

/// Pairing with a hub, two steps: a code is asked first; once the hub's
/// action button is pressed, the code gives the token.
class DirigeraPairing {
  DirigeraPairing(this._http, this.host) : _verifier = _newVerifier();

  final LanRequests _http;
  final String host;
  final String _verifier;
  String? _code;

  /// The hub's certificate as seen when pairing (kept, then required).
  String? certificate;

  static String _newVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return [for (var i = 0; i < 128; i++) chars[r.nextInt(chars.length)]]
        .join();
  }

  /// PKCE (S256) for [verifier].
  static String challenge(String verifier) => base64Url
      .encode(hash.sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  /// One try: the token, or `null` while the button is not pressed.
  Future<String?> tryLink() async {
    final code = _code ??= await _authorize();
    final r = await _http.send(
      'POST',
      Uri.parse('https://$host:8443/v1/oauth/token'),
      headers: const {'content-type': 'application/x-www-form-urlencoded'},
      body: utf8.encode(
        Uri(
          queryParameters: {
            'code': code,
            'name': 'open-smart-home',
            'grant_type': 'authorization_code',
            'code_verifier': _verifier,
          },
        ).query,
      ),
      insecure: true,
    );
    final token = r.ok && r.json is Map
        ? (r.json as Map)['access_token']
        : null;
    if (token is! String) return null;
    certificate = r.certificate;
    return token;
  }

  Future<String> _authorize() async {
    final r = await _http.send(
      'GET',
      Uri.https('$host:8443', '/v1/oauth/authorize', {
        'audience': 'homesmart.local',
        'response_type': 'code',
        'code_challenge': challenge(_verifier),
        'code_challenge_method': 'S256',
      }),
      insecure: true,
    );
    final code = r.json is Map ? (r.json as Map)['code'] : null;
    if (code is! String) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'dirigera ${r.status}',
      );
    }
    return code;
  }
}

List<SmartHomeDevice> parseDirigera(ConfiguredDevice hub, List<Object?> list) {
  final out = <SmartHomeDevice>[];
  for (final item in list) {
    if (item is! Map) continue;
    final id = item['id'];
    final type = item['deviceType'] ?? item['type'];
    if (id is! String || type is! String) continue;
    final a = (item['attributes'] as Map?)?.cast<String, Object?>() ?? const {};
    final receives = {
      for (final c
          in ((item['capabilities'] as Map?)?['canReceive'] as List?) ??
              const [])
        if (c is String) c,
    };
    final name = (a['customName'] as String?)?.trim();
    final label = name == null || name.isEmpty
        ? (a['model'] as String? ?? 'IKEA')
        : name;
    final reachable = item['isReachable'] != false;
    final battery = (a['batteryPercentage'] as num?)?.round();
    final key = '${hub.key}:$id';
    SmartHomeDevice make(
      String part,
      String name,
      DeviceKind kind,
      Set<Capability> capabilities,
      DeviceState state, {
      DeviceLimits limits = DeviceLimits.none,
    }) => SmartHomeDevice(
      id: '$key:$part',
      sourceId: id,
      deviceId: key,
      name: name,
      kind: kind,
      protocol: DeviceProtocol.zigbee,
      manufacturer: a['manufacturer'] as String? ?? 'IKEA',
      model: a['model'] as String?,
      available: reachable,
      capabilities: capabilities,
      state: state,
      limits: limits,
      metadata: DeviceMetadata(batteryPercent: battery),
    );
    final on = a['isOn'] == true;
    switch (type) {
      case 'light':
        final color = receives.contains('colorHue');
        final white = receives.contains('colorTemperature');
        final t1 = (a['colorTemperatureMin'] as num?)?.round();
        final t2 = (a['colorTemperatureMax'] as num?)?.round();
        final mode = a['colorMode'];
        out.add(
          make(
            'light',
            label,
            color
                ? DeviceKind.rgbLight
                : receives.contains('lightLevel')
                ? DeviceKind.dimmableLight
                : DeviceKind.light,
            {
              Capability.power,
              if (receives.contains('lightLevel')) Capability.brightness,
              if (white) Capability.colorTemperature,
              if (color) Capability.rgb,
            },
            DeviceState(
              raw: on ? 'on' : 'off',
              isOn: on,
              brightnessPercent: on ? (a['lightLevel'] as num?)?.round() : null,
              colorTemperatureKelvin: on && white && mode != 'color'
                  ? (a['colorTemperature'] as num?)?.round()
                  : null,
              rgb: on && color && mode == 'color'
                  ? hsvToRgb(
                      (a['colorHue'] as num? ?? 0).toDouble(),
                      (a['colorSaturation'] as num? ?? 0).toDouble(),
                    )
                  : null,
            ),
            // The hub names them the other way round (min is the coolest).
            limits: t1 != null && t2 != null
                ? DeviceLimits(
                    minColorTemperatureKelvin: min(t1, t2),
                    maxColorTemperatureKelvin: max(t1, t2),
                  )
                : DeviceLimits.none,
          ),
        );
      case 'outlet':
        out.add(
          make('switch', label, DeviceKind.outlet, const {
            Capability.power,
          }, DeviceState(raw: on ? 'on' : 'off', isOn: on)),
        );
        if (a['currentActivePower'] case final num w) {
          out.add(
            make('power', '$label · W', DeviceKind.powerMeter, const {
              Capability.powerConsumption,
            }, DeviceState(raw: '$w', numericValue: w.toDouble(), unit: 'W')),
          );
        }
      case 'blinds':
        final level = (a['blindsCurrentLevel'] as num?)?.round();
        final position = level == null ? null : 100 - level;
        out.add(
          make(
            'cover',
            label,
            DeviceKind.blind,
            const {Capability.open, Capability.close, Capability.position},
            DeviceState(
              raw: position == 0 ? 'closed' : 'open',
              coverState: position == 0 ? CoverState.closed : CoverState.open,
              position: position,
            ),
          ),
        );
      case 'motionSensor' || 'occupancySensor':
        final active = a['isDetected'] == true;
        out.add(
          make(
            'motion',
            label,
            DeviceKind.motionSensor,
            const {},
            DeviceState(raw: active ? 'on' : 'off', isActive: active),
          ),
        );
      case 'openCloseSensor':
        final open = a['isOpen'] == true;
        out.add(
          make(
            'open',
            label,
            DeviceKind.contactSensor,
            const {},
            DeviceState(raw: open ? 'on' : 'off', isActive: open),
          ),
        );
      case 'waterSensor':
        final wet = a['waterLeakDetected'] == true;
        out.add(
          make(
            'moisture',
            label,
            DeviceKind.waterLeakSensor,
            const {},
            DeviceState(raw: wet ? 'on' : 'off', isActive: wet),
          ),
        );
      case 'environmentSensor':
        if (a['currentTemperature'] case final num t) {
          out.add(
            make(
              'temperature',
              label,
              DeviceKind.temperatureSensor,
              const {Capability.currentTemperature},
              DeviceState(
                raw: '$t',
                numericValue: t.toDouble(),
                currentTemperature: t.toDouble(),
                unit: '°C',
              ),
            ),
          );
        }
        if (a['currentRH'] case final num h) {
          out.add(
            make(
              'humidity',
              '$label · %',
              DeviceKind.humiditySensor,
              const {Capability.humidity},
              DeviceState(
                raw: '$h',
                numericValue: h.toDouble(),
                currentHumidity: h.toDouble(),
                unit: '%',
              ),
            ),
          );
        }
    }
  }
  return out;
}

/// Whether [host] is a DIRIGERA hub (its API answers, without a token,
/// with 401).
Future<bool> dirigeraProbe(LanRequests http, String host) async {
  try {
    final r = await http.send(
      'GET',
      Uri.parse('https://$host:8443/v1/devices'),
      insecure: true,
      timeout: const Duration(seconds: 3),
    );
    return r.status == 401;
  } on AppFailure catch (e) {
    return e.kind == FailureKind.authentication;
  }
}
