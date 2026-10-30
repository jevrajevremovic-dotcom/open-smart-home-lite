import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'color_math.dart';
import 'lan_transport.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// Nanoleaf panels, Shapes, Lines and Elements over their local REST API
/// (port 16021). Paired by holding the power button until it blinks
/// ([nanoleafLink]); the token it gives is kept like a password. The
/// panel and its scene ("effect") are two devices.
class NanoleafAdapter extends PolledAdapter {
  NanoleafAdapter(this._http, {this.tokens, super.pollEvery});

  final LanRequests _http;
  final Future<String?> Function(String key)? tokens;
  final Map<String, String?> _tokens = {};

  static const port = 16021;

  @override
  String get id => 'nanoleaf';

  @override
  void configure(List<ConfiguredDevice> devices) {
    _tokens.clear();
    super.configure(devices);
  }

  Future<Uri> _uri(ConfiguredDevice device, String path) async {
    final token = _tokens[device.key] ??= await tokens?.call(device.key);
    if (token == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'nanoleaf: not paired',
      );
    }
    return Uri.parse('http://${device.host}:$port/api/v1/$token$path');
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final r = await _http.send('GET', await _uri(device, '/'));
    final json = r.json;
    if (!r.ok || json is! Map) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'nanoleaf ${r.status}',
      );
    }
    return parseNanoleaf(device, json.cast<String, Object?>());
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    if (command case SelectOption(:final option)) {
      await _put(device, '/effects', {'select': option});
      return;
    }
    final state = <String, Object?>{
      ...switch (command) {
        TurnOn() => {
          'on': {'value': true},
        },
        TurnOff() => {
          'on': {'value': false},
        },
        Toggle() => {
          'on': {'value': channel.state.isOn != true},
        },
        SetBrightness(:final percent) when percent == 0 => {
          'on': {'value': false},
        },
        SetBrightness(:final percent) => {
          'brightness': {'value': percent},
        },
        SetColorTemperature(:final kelvin) => {
          'ct': {'value': kelvin.clamp(1200, 6500)},
        },
        SetRgbColor(:final color) => () {
          final hsv = rgbToHsv(color);
          return {
            'hue': {'value': hsv.hue.round()},
            'sat': {'value': (hsv.saturation * 100).round()},
          };
        }(),
        _ => throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} for Nanoleaf',
        ),
      },
    };
    // Brightness or colour on panels that are off: on as well.
    if (!state.containsKey('on') && channel.state.isOn != true) {
      state['on'] = {'value': true};
    }
    await _put(device, '/state', state);
  }

  Future<void> _put(
    ConfiguredDevice device,
    String path,
    Map<String, Object?> body,
  ) async {
    final b = jsonBody(body);
    final r = await _http.send(
      'PUT',
      await _uri(device, path),
      headers: b.headers,
      body: b.body,
    );
    if (!r.ok) {
      throw AppFailure(
        FailureKind.server,
        debugMessage: 'nanoleaf ${r.status}',
      );
    }
  }
}

/// The token while the panel is in pairing mode (power button held
/// 5–7 s); `null` otherwise.
Future<String?> nanoleafLink(LanRequests http, String host) async {
  final r = await http.send(
    'POST',
    Uri.parse('http://$host:${NanoleafAdapter.port}/api/v1/new'),
  );
  final token = r.ok && r.json is Map ? (r.json as Map)['auth_token'] : null;
  return token is String && token.isNotEmpty ? token : null;
}

/// Whether [host] is a Nanoleaf (it answers its API, without a token, with
/// 401).
Future<bool> nanoleafProbe(LanRequests http, String host) async {
  try {
    final r = await http.send(
      'GET',
      Uri.parse('http://$host:${NanoleafAdapter.port}/api/v1/'),
      timeout: const Duration(seconds: 3),
    );
    return r.status == 401 || r.status == 403;
  } on AppFailure catch (e) {
    return e.kind == FailureKind.authentication;
  }
}

List<SmartHomeDevice> parseNanoleaf(
  ConfiguredDevice device,
  Map<String, Object?> info,
) {
  Map<String, Object?> m(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};
  num? value(Object? v) => m(v)['value'] as num?;
  final state = m(info['state']);
  final effects = m(info['effects']);
  final on = m(state['on'])['value'] == true;
  final mode = state['colorMode'];
  final hue = value(state['hue']);
  final sat = value(state['sat']);
  final ct = value(state['ct']);
  final name = info['name'] as String? ?? device.label ?? 'Nanoleaf';
  final list = [
    for (final e in (effects['effectsList'] as List?) ?? const [])
      if (e is String) e,
  ];
  final selected = effects['select'] as String?;
  return [
    SmartHomeDevice(
      id: '${device.key}:light',
      sourceId: device.host,
      deviceId: device.key,
      name: name,
      kind: DeviceKind.rgbLight,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'Nanoleaf',
      model: info['model'] as String? ?? device.model,
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
        brightnessPercent: on ? value(state['brightness'])?.round() : null,
        colorTemperatureKelvin: on && mode == 'ct' ? ct?.round() : null,
        rgb: on && mode == 'hs' && hue != null && sat != null
            ? hsvToRgb(hue.toDouble(), sat / 100)
            : null,
      ),
      limits: const DeviceLimits(
        minColorTemperatureKelvin: 1200,
        maxColorTemperatureKelvin: 6500,
      ),
    ),
    if (list.isNotEmpty)
      SmartHomeDevice(
        id: '${device.key}:effect',
        sourceId: device.host,
        deviceId: device.key,
        name: '$name · FX',
        kind: DeviceKind.select,
        protocol: DeviceProtocol.wifi,
        manufacturer: 'Nanoleaf',
        available: true,
        capabilities: const {Capability.selectOption},
        state: DeviceState(
          raw: selected ?? 'unknown',
          // "*Solid*" and the like: no scene, a plain colour.
          textValue: selected != null && !selected.startsWith('*')
              ? selected
              : null,
        ),
        limits: DeviceLimits(options: list),
      ),
  ];
}
