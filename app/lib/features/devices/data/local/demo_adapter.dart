import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'device_adapter.dart';

/// Rooms of the demo home.
const demoRooms = {
  'living': Room(id: 'living', name: 'Dnevna soba', icon: 'mdi:sofa'),
  'bedroom': Room(id: 'bedroom', name: 'Spavaća soba', icon: 'mdi:bed'),
  'kitchen': Room(id: 'kitchen', name: 'Kuhinja', icon: 'mdi:stove'),
};

/// A small home in memory that obeys its commands, so the app can be tried
/// (and tested) without any device.
class DemoAdapter extends DeviceAdapter {
  DemoAdapter({this.latency = const Duration(milliseconds: 150)});

  /// How long a device takes to answer.
  final Duration latency;

  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  final Map<String, _DemoDevice> _devices = {
    for (final d in _initial()) d.id: d,
  };
  late List<SmartHomeDevice> _current = _build();

  @override
  String get id => 'demo';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => _current;

  @override
  Future<void> start() async {}

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final d = _devices[device.id];
    if (d == null) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} unknown',
      );
    }
    await Future<void>.delayed(latency);
    switch (command) {
      case TurnOn():
        d.on = true;
      case TurnOff():
        d.on = false;
      case Toggle():
        d.on = !d.on;
      case SetBrightness(:final percent):
        d.on = percent > 0;
        if (percent > 0) d.brightness = percent;
      case SetColorTemperature(:final kelvin):
        d
          ..on = true
          ..kelvin = kelvin
          ..rgb = null;
      case SetRgbColor(:final color):
        d
          ..on = true
          ..rgb = color
          ..kelvin = null;
      case OpenCover():
        d.position = 100;
      case CloseCover():
        d.position = 0;
      case SetCoverPosition(:final percent):
        d.position = percent;
      case StopCover():
        break;
      case SetTargetTemperature(:final temperature):
        d.target = temperature;
      case SetHvacMode(:final mode):
        d.hvacMode = mode;
      case LockDevice():
        d.locked = true;
      case UnlockDevice():
        d.locked = false;
      default:
        throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} not in the demo',
        );
    }
    _current = _build();
    if (!_controller.isClosed) _controller.add(_current);
  }

  @override
  Future<void> dispose() => _controller.close();

  List<SmartHomeDevice> _build() => [
    for (final d in _devices.values) d.build(),
  ];

  static List<_DemoDevice> _initial() => [
    _DemoDevice('demo:living_ceiling', 'Plafonjera', 'living', _Type.light)
      ..on = true
      ..brightness = 70
      ..kelvin = 3000,
    _DemoDevice('demo:living_strip', 'LED traka', 'living', _Type.rgbLight)
      ..rgb = const RgbColor(255, 120, 40),
    _DemoDevice('demo:living_tv_plug', 'Utičnica TV', 'living', _Type.outlet)
      ..on = true,
    _DemoDevice('demo:living_blind', 'Roletna', 'living', _Type.blind)
      ..position = 100,
    _DemoDevice('demo:living_temp', 'Temperatura', 'living', _Type.temperature)
      ..value = 22.4,
    _DemoDevice('demo:bedroom_lamp', 'Lampa', 'bedroom', _Type.light)
      ..brightness = 40
      ..kelvin = 2700,
    _DemoDevice('demo:bedroom_ac', 'Klima', 'bedroom', _Type.climate)
      ..target = 23
      ..value = 25.1,
    _DemoDevice('demo:kitchen_light', 'Svetlo', 'kitchen', _Type.light)
      ..brightness = 100
      ..kelvin = 4000,
    _DemoDevice('demo:kitchen_humidity', 'Vlažnost', 'kitchen', _Type.humidity)
      ..value = 48,
    _DemoDevice('demo:front_door', 'Ulazna vrata', null, _Type.lock),
  ];
}

enum _Type {
  light,
  rgbLight,
  outlet,
  blind,
  temperature,
  humidity,
  climate,
  lock,
}

class _DemoDevice {
  _DemoDevice(this.id, this.name, this.roomId, this.type);

  final String id;
  final String name;
  final String? roomId;
  final _Type type;

  bool on = false;
  int brightness = 100;
  int? kelvin;
  RgbColor? rgb;
  int position = 0;
  double value = 0;
  double target = 21;
  String hvacMode = 'cool';
  bool locked = true;

  SmartHomeDevice build() {
    final (kind, capabilities, state, limits) = switch (type) {
      _Type.light => (
        DeviceKind.dimmableLight,
        {Capability.power, Capability.brightness, Capability.colorTemperature},
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on ? brightness : null,
          colorTemperatureKelvin: on ? kelvin : null,
        ),
        const DeviceLimits(
          minColorTemperatureKelvin: 2700,
          maxColorTemperatureKelvin: 6500,
        ),
      ),
      _Type.rgbLight => (
        DeviceKind.rgbLight,
        {
          Capability.power,
          Capability.brightness,
          Capability.rgb,
          Capability.colorTemperature,
        },
        DeviceState(
          raw: on ? 'on' : 'off',
          isOn: on,
          brightnessPercent: on ? brightness : null,
          colorTemperatureKelvin: on ? kelvin : null,
          rgb: on ? rgb : null,
        ),
        const DeviceLimits(
          minColorTemperatureKelvin: 2700,
          maxColorTemperatureKelvin: 6500,
        ),
      ),
      _Type.outlet => (
        DeviceKind.outlet,
        {Capability.power},
        DeviceState(raw: on ? 'on' : 'off', isOn: on),
        DeviceLimits.none,
      ),
      _Type.blind => (
        DeviceKind.blind,
        {
          Capability.open,
          Capability.close,
          Capability.stop,
          Capability.position,
        },
        DeviceState(
          raw: position > 0 ? 'open' : 'closed',
          coverState: position > 0 ? CoverState.open : CoverState.closed,
          position: position,
        ),
        DeviceLimits.none,
      ),
      _Type.temperature => (
        DeviceKind.temperatureSensor,
        {Capability.currentTemperature},
        DeviceState(
          raw: '$value',
          numericValue: value,
          currentTemperature: value,
          unit: '°C',
        ),
        DeviceLimits.none,
      ),
      _Type.humidity => (
        DeviceKind.humiditySensor,
        {Capability.humidity},
        DeviceState(
          raw: '$value',
          numericValue: value,
          currentHumidity: value,
          unit: '%',
        ),
        DeviceLimits.none,
      ),
      _Type.climate => (
        DeviceKind.climate,
        {
          Capability.power,
          Capability.targetTemperature,
          Capability.currentTemperature,
          Capability.hvacMode,
          Capability.heating,
          Capability.cooling,
        },
        DeviceState(
          raw: hvacMode,
          isOn: hvacMode != 'off',
          hvacMode: hvacMode,
          targetTemperature: target,
          currentTemperature: value,
        ),
        const DeviceLimits(
          minTemperature: 16,
          maxTemperature: 30,
          temperatureStep: 0.5,
          hvacModes: ['off', 'cool', 'heat', 'auto'],
        ),
      ),
      _Type.lock => (
        DeviceKind.lock,
        {Capability.lock, Capability.unlock},
        DeviceState(
          raw: locked ? 'locked' : 'unlocked',
          lockState: locked ? DoorLockState.locked : DoorLockState.unlocked,
        ),
        DeviceLimits.none,
      ),
    };
    return SmartHomeDevice(
      id: id,
      sourceId: id,
      name: name,
      roomId: roomId,
      kind: kind,
      protocol: DeviceProtocol.virtual,
      available: true,
      capabilities: capabilities,
      state: state,
      limits: limits,
    );
  }
}
