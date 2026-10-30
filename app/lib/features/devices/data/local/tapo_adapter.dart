import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'color_math.dart';
import 'klap.dart';
import 'local_home.dart';
import 'polled_adapter.dart';

/// TP-Link Tapo plugs and bulbs (P100/P110/P115, L510/L530/L900…) over
/// KLAP, with the TP-Link account they are bound to ([TpLinkAccount],
/// kept like a password). Plugs that measure power (P110, P115) show it.
class TapoAdapter extends PolledAdapter {
  TapoAdapter(this._klap, {this.accounts, super.pollEvery});

  final KlapClient _klap;
  final Future<String?> Function(String key)? accounts;
  final Map<String, TpLinkAccount?> _accounts = {};

  @override
  String get id => 'tapo';

  @override
  void configure(List<ConfiguredDevice> devices) {
    _accounts.clear();
    super.configure(devices);
  }

  Future<Map<String, Object?>> _call(
    ConfiguredDevice device,
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final account = _accounts[device.key] ??= TpLinkAccount.decode(
      await accounts?.call(device.key),
    );
    if (account == null) {
      throw const AppFailure(
        FailureKind.authentication,
        debugMessage: 'tapo: no account',
      );
    }
    return tapoResult(
      await _klap.send(device.host, account, tapoRequest(method, params)),
    );
  }

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async {
    final info = await _call(device, 'get_device_info');
    double? watts;
    if (tapoMeasures(info['model'] as String?)) {
      try {
        watts =
            ((await _call(device, 'get_current_power'))['current_power']
                    as num?)
                ?.toDouble();
      } on AppFailure {
        // Older firmware: no reading.
      }
    }
    return parseTapo(device, info, watts: watts);
  }

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final params = switch (command) {
      TurnOn() => {'device_on': true},
      TurnOff() => {'device_on': false},
      Toggle() => {'device_on': channel.state.isOn != true},
      SetBrightness(:final percent) when percent == 0 => {'device_on': false},
      SetBrightness(:final percent) => {
        'device_on': true,
        'brightness': percent.clamp(1, 100),
      },
      SetColorTemperature(:final kelvin) => {
        'device_on': true,
        'color_temp': kelvin.clamp(2500, 6500),
      },
      SetRgbColor(:final color) => () {
        final hsv = rgbToHsv(color);
        return {
          'device_on': true,
          'hue': hsv.hue.round(),
          'saturation': (hsv.saturation * 100).round(),
          'color_temp': 0,
        };
      }(),
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for Tapo',
      ),
    };
    await _call(device, 'set_device_info', params);
  }
}

Map<String, Object?> tapoRequest(
  String method, [
  Map<String, Object?>? params,
]) => {
  'method': method,
  'params': ?params,
  'request_time_milis': DateTime.now().millisecondsSinceEpoch,
};

/// The answer's `result`; throws for an `error_code` other than 0.
Map<String, Object?> tapoResult(Map<String, Object?> answer) {
  final code = answer['error_code'];
  if (code != 0) {
    throw AppFailure(FailureKind.server, debugMessage: 'tapo error $code');
  }
  final r = answer['result'];
  return r is Map ? r.cast<String, Object?>() : const {};
}

bool tapoMeasures(String? model) {
  final m = (model ?? '').toUpperCase();
  return m.startsWith('P110') || m.startsWith('P115') || m.startsWith('P125');
}

String? tapoNickname(Map<String, Object?> info) {
  final n = info['nickname'];
  if (n is! String || n.isEmpty) return null;
  try {
    return utf8.decode(base64.decode(n));
  } on FormatException {
    return n;
  }
}

List<SmartHomeDevice> parseTapo(
  ConfiguredDevice device,
  Map<String, Object?> info, {
  double? watts,
}) {
  final type = (info['type'] as String? ?? '').toUpperCase();
  final bulb = type.contains('BULB');
  final on = info['device_on'] == true;
  final name = tapoNickname(info) ?? device.label ?? 'Tapo';
  final model = info['model'] as String? ?? device.model;
  final color = bulb && info.containsKey('hue');
  final temp = (info['color_temp'] as num?)?.round() ?? 0;
  final signal = (info['rssi'] as num?)?.toDouble();
  final metadata = DeviceMetadata(signalStrength: signal, signalUnit: 'dBm');
  return [
    SmartHomeDevice(
      id: '${device.key}:${bulb ? 'light' : 'switch'}',
      sourceId: device.host,
      deviceId: device.key,
      name: name,
      kind: !bulb
          ? DeviceKind.outlet
          : color
          ? DeviceKind.rgbLight
          : DeviceKind.dimmableLight,
      protocol: DeviceProtocol.wifi,
      manufacturer: 'TP-Link',
      model: model,
      available: true,
      capabilities: {
        Capability.power,
        if (bulb) Capability.brightness,
        if (bulb && info.containsKey('color_temp')) Capability.colorTemperature,
        if (color) Capability.rgb,
      },
      state: DeviceState(
        raw: on ? 'on' : 'off',
        isOn: on,
        brightnessPercent: on && bulb
            ? (info['brightness'] as num?)?.round()
            : null,
        colorTemperatureKelvin: on && bulb && temp > 0 ? temp : null,
        rgb: on && color && temp == 0
            ? hsvToRgb(
                (info['hue'] as num? ?? 0).toDouble(),
                (info['saturation'] as num? ?? 0) / 100,
              )
            : null,
      ),
      limits: bulb
          ? const DeviceLimits(
              minColorTemperatureKelvin: 2500,
              maxColorTemperatureKelvin: 6500,
            )
          : DeviceLimits.none,
      metadata: metadata,
    ),
    if (watts != null)
      SmartHomeDevice(
        id: '${device.key}:power',
        sourceId: device.host,
        deviceId: device.key,
        name: '$name · W',
        kind: DeviceKind.powerMeter,
        protocol: DeviceProtocol.wifi,
        manufacturer: 'TP-Link',
        model: model,
        available: true,
        capabilities: const {Capability.powerConsumption},
        state: DeviceState(raw: '$watts', numericValue: watts, unit: 'W'),
        metadata: metadata,
        isAuxiliary: true,
      ),
  ];
}

/// Who the Tapo at [host] is, with [account]: id (MAC), name, model; or
/// `null` when it is not a Tapo. Throws `AppFailure(authentication)` for
/// a wrong account.
Future<({String id, String? name, String? model})?> tapoIdentify(
  KlapClient klap,
  String host,
  TpLinkAccount account,
) async {
  final Map<String, Object?> info;
  try {
    info = tapoResult(
      await klap.send(host, account, tapoRequest('get_device_info')),
    );
  } on AppFailure catch (e) {
    if (e.kind == FailureKind.authentication) rethrow;
    return null;
  }
  final mac = (info['mac'] as String? ?? info['device_id'] as String? ?? '')
      .toLowerCase()
      .replaceAll(RegExp('[^0-9a-z]'), '');
  if (mac.isEmpty) return null;
  return (id: mac, name: tapoNickname(info), model: info['model'] as String?);
}
