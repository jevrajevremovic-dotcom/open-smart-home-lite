import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'lan_http.dart';
import 'local_home.dart';
import 'polled_adapter.dart';
import 'shelly_adapter.dart' show normalizeMac;

/// Devices with Tasmota firmware (Sonoff and many other relays, plugs and
/// bulbs), over the web commands API (`/cm?cmnd=…`): relays (`POWER1…`),
/// a dimmable or colour light, energy and temperature/humidity sensors.
class TasmotaAdapter extends PolledAdapter {
  TasmotaAdapter(this._http, {super.pollEvery});

  final LanHttp _http;

  @override
  String get id => 'tasmota';

  @override
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device) async =>
      parseTasmota(device, _map(await _cmd(device.host, 'Status 0')));

  @override
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  ) async {
    final part = channel.id.split(':').last; // power1, power
    final power = part.startsWith('power') ? 'Power${part.substring(5)}' : '';
    final cmnd = switch (command) {
      TurnOn() when power.isNotEmpty => '$power On',
      TurnOff() when power.isNotEmpty => '$power Off',
      Toggle() when power.isNotEmpty => '$power Toggle',
      SetBrightness(:final percent) => 'Dimmer $percent',
      SetRgbColor(:final color) =>
        'Color ${[color.red, color.green, color.blue].map((c) => c.toRadixString(16).padLeft(2, '0')).join()}',
      _ => throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${command.runtimeType} for ${channel.id}',
      ),
    };
    await _cmd(device.host, cmnd);
  }

  Future<Object?> _cmd(String host, String cmnd) =>
      _http.get(host, '/cm', query: {'cmnd': cmnd});
}

/// What `Status 0` says about a device, if it is a Tasmota.
typedef TasmotaInfo = ({String mac, String? name, String? module});

TasmotaInfo? parseTasmotaInfo(Object? json) {
  final j = _map(json);
  final mac = _map(j['StatusNET'])['Mac'];
  if (mac is! String || !j.containsKey('Status')) return null;
  final status = _map(j['Status']);
  final friendly = status['FriendlyName'];
  return (
    mac: normalizeMac(mac),
    name:
        status['DeviceName'] as String? ??
        (friendly is List ? friendly.firstOrNull as String? : null),
    module: _map(j['StatusFWR'])['Hardware'] as String?,
  );
}

List<SmartHomeDevice> parseTasmota(
  ConfiguredDevice device,
  Map<String, Object?> status,
) {
  final info = _map(status['Status']);
  final sts = _map(status['StatusSTS']);
  final sns = _map(status['StatusSNS']);
  final friendly = switch (info['FriendlyName']) {
    final List<Object?> names => [for (final n in names) '$n'],
    _ => const <String>[],
  };
  final deviceName =
      info['DeviceName'] as String? ??
      friendly.firstOrNull ??
      device.label ??
      'Tasmota';
  final metadata = DeviceMetadata(
    signalStrength: _num(_map(sts['Wifi'])['Signal']),
    signalUnit: 'dBm',
  );
  SmartHomeDevice make(
    String part,
    String name,
    DeviceKind kind,
    Set<Capability> capabilities,
    DeviceState state,
  ) => SmartHomeDevice(
    id: '${device.key}:$part',
    sourceId: part,
    deviceId: device.key,
    name: name,
    kind: kind,
    protocol: DeviceProtocol.wifi,
    manufacturer: 'Tasmota',
    model: device.model,
    available: true,
    capabilities: capabilities,
    state: state,
    metadata: metadata,
  );

  // POWER (one relay) or POWER1…POWERn.
  final powers = [
    for (final key in sts.keys)
      if (RegExp(r'^POWER\d*$').hasMatch(key)) key,
  ]..sort();
  final dimmer = _num(sts['Dimmer'])?.round();
  final color = sts['Color'];
  final hasColor =
      color is String && color.length >= 6 && !color.contains(',') ||
      sts.containsKey('HSBColor');
  final out = <SmartHomeDevice>[];
  for (final (i, key) in powers.indexed) {
    final on = sts[key] == 'ON';
    final number = key.substring(5);
    final name =
        friendly.elementAtOrNull(number.isEmpty ? 0 : int.parse(number) - 1) ??
        (powers.length > 1 ? '$deviceName ${i + 1}' : deviceName);
    // A single channel with a dimmer is the light itself.
    final light = powers.length == 1 && dimmer != null;
    out.add(
      make(
        'power$number',
        name,
        light
            ? (hasColor ? DeviceKind.rgbLight : DeviceKind.dimmableLight)
            : DeviceKind.switchDevice,
        {
          Capability.power,
          if (light) Capability.brightness,
          if (light && hasColor) Capability.rgb,
        },
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: light && on ? dimmer : null,
          rgb: light && on && hasColor && color is String ? _rgb(color) : null,
        ),
      ),
    );
  }

  final power = _num(_map(sns['ENERGY'])['Power']);
  if (power != null) {
    out.add(
      make('energy_power', '$deviceName · W', DeviceKind.powerMeter, {
        Capability.powerConsumption,
      }, DeviceState(raw: '$power', numericValue: power, unit: 'W')),
    );
  }
  final unit = sns['TempUnit'] == 'F' ? '°F' : '°C';
  for (final MapEntry(:key, :value) in sns.entries) {
    final sensor = _map(value);
    final t = _num(sensor['Temperature']);
    final h = _num(sensor['Humidity']);
    final slug = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (t != null) {
      out.add(
        make(
          '${slug}_temperature',
          '$deviceName · $key',
          DeviceKind.temperatureSensor,
          {Capability.currentTemperature},
          DeviceState(
            raw: '$t',
            numericValue: t,
            currentTemperature: t,
            unit: unit,
          ),
        ),
      );
    }
    if (h != null) {
      out.add(
        make(
          '${slug}_humidity',
          '$deviceName · $key',
          DeviceKind.humiditySensor,
          {Capability.humidity},
          DeviceState(
            raw: '$h',
            numericValue: h,
            currentHumidity: h,
            unit: '%',
          ),
        ),
      );
    }
  }
  return out;
}

/// `FF8000` (or `FF8000FF` with white) → rgb.
RgbColor? _rgb(String hex) {
  final v = int.tryParse(hex.substring(0, 6), radix: 16);
  return v == null ? null : RgbColor(v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF);
}

Map<String, Object?> _map(Object? json) => json is Map
    ? {
        for (final e in json.entries)
          if (e.key is String) e.key as String: e.value,
      }
    : const {};

double? _num(Object? v) => v is num ? v.toDouble() : null;
