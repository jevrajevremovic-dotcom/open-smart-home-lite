import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';

/// Devices whose current state can be stored in a scene.
bool canStoreInScene(SmartHomeDevice d) =>
    d.available &&
    !d.isAuxiliary &&
    (d.kind.isLight ||
        d.kind == DeviceKind.switchDevice ||
        d.kind == DeviceKind.outlet ||
        d.kind == DeviceKind.fan ||
        d.kind == DeviceKind.blind ||
        d.kind == DeviceKind.curtain ||
        d.kind == DeviceKind.climate ||
        d.kind == DeviceKind.thermostat ||
        d.kind == DeviceKind.mediaPlayer ||
        d.kind == DeviceKind.speaker ||
        d.kind == DeviceKind.television);

/// The scene entry for [d]'s current state (HA scene config format:
/// `state` plus the attributes HA restores).
Map<String, Object?> sceneEntryFor(SmartHomeDevice d) {
  final s = d.state;
  if (d.kind.isLight) {
    return {
      'state': s.isOn == true ? 'on' : 'off',
      if (s.isOn == true && s.brightnessPercent != null)
        'brightness': (s.brightnessPercent! * 255 / 100).round(),
      if (s.isOn == true && s.rgb != null)
        'rgb_color': [s.rgb!.red, s.rgb!.green, s.rgb!.blue]
      else if (s.isOn == true && s.colorTemperatureKelvin != null)
        'color_temp_kelvin': s.colorTemperatureKelvin,
    };
  }
  switch (d.kind) {
    case DeviceKind.blind || DeviceKind.curtain:
      return {
        'state': s.coverState == CoverState.closed ? 'closed' : 'open',
        'current_position': ?s.position,
      };
    case DeviceKind.climate || DeviceKind.thermostat:
      return {
        'state': s.hvacMode ?? s.raw,
        'temperature': ?s.targetTemperature,
      };
    case DeviceKind.fan:
      return {
        'state': s.isOn == true ? 'on' : 'off',
        if (s.isOn == true) 'percentage': ?s.percentage,
      };
    default:
      return {'state': s.isOn == true ? 'on' : 'off'};
  }
}

/// HA scene config (`/api/config/scene/config/<id>`).
Map<String, Object?> sceneConfig(
  String id,
  String name,
  Iterable<SmartHomeDevice> devices,
) => {
  'id': id,
  'name': name,
  'entities': {for (final d in devices) d.sourceId: sceneEntryFor(d)},
};
