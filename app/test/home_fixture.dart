import 'dart:async';
import 'dart:convert';

import 'package:open_smart_home_lite/features/devices/data/local/device_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

/// The rooms of [HomeFixture]'s house.
const fixtureRooms = <String, Room>{
  'living_room': Room(id: 'living_room', name: 'Dnevna soba'),
  'kitchen': Room(id: 'kitchen', name: 'Kuhinja'),
  'hallway': Room(id: 'hallway', name: 'Hodnik'),
  'bedroom': Room(id: 'bedroom', name: 'Spavaća soba'),
  'yard': Room(id: 'yard', name: 'Dvorište'),
  'garage': Room(id: 'garage', name: 'Garaža'),
};

/// The house's scene, `routine:scene_movie_night`, as saved.
final fixtureRoutines = jsonEncode({
  'scenes': [
    {
      'id': 'movie_night',
      'name': 'Filmsko veče',
      'actions': [
        {
          'device': 'fx:light.living_room_ambient',
          'do': 'brightness',
          'value': 35,
        },
        {'device': 'fx:light.living_room_main', 'do': 'off'},
      ],
    },
  ],
  'automations': <Object>[],
});

/// A whole house of every kind of device the app shows, answering commands
/// as real ones would. Ids are `fx:<kind>.<name>`, e.g.
/// `fx:light.living_room_main`.
///
/// For tests of screens that need more than the demo home: a lock that
/// jams, an alarm, a speaker that plays, people at home…
class HomeFixture extends DeviceAdapter {
  /// With [clock], devices report when they last changed (by that clock).
  HomeFixture({List<SmartHomeDevice>? devices, DateTime? now, this.clock})
    : _devices = {
        for (final d in devices ?? fixtureDevices(now ?? DateTime.now()))
          d.id: d,
      } {
    running = this;
  }

  final DateTime Function()? clock;

  /// The fixture of the test that is running.
  static late HomeFixture running;

  final Map<String, SmartHomeDevice> _devices;
  final List<(String, DeviceCommand)> sent = [];
  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();

  @override
  String get id => 'fx';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => List.unmodifiable(_devices.values);

  @override
  Future<void> start() async {}

  SmartHomeDevice operator [](String id) => _devices[_full(id)]!;

  static String _full(String id) => id.startsWith('fx:') ? id : 'fx:$id';

  /// The device changed by itself (a sensor, a person coming home…).
  void set(String id, DeviceState state, {bool? available}) {
    final d = this[id];
    update(
      _with(d, state: state, available: available, lastChanged: clock?.call()),
    );
  }

  /// The device's state as its device would report it: `on`, `locked`…
  String? stateOf(String id) => _devices[_full(id)]?.state.raw;

  /// The device reports [raw] by itself, as [stateOf] reads it.
  void setRaw(String id, String raw) {
    final d = this[id];
    final s = d.state;
    final on = raw == 'on';
    final unavailable = raw == 'unavailable';
    set(id, switch (d.kind) {
      _ when unavailable => DeviceState(raw: raw),
      DeviceKind.lock => state(
        s,
        raw: raw,
        lockState: DoorLockState.values.where((l) => l.name == raw).firstOrNull,
      ),
      DeviceKind.alarm => state(
        s,
        raw: raw,
        alarmState: switch (raw) {
          'disarmed' => AlarmState.disarmed,
          'armed_home' => AlarmState.armedHome,
          'armed_away' => AlarmState.armedAway,
          'armed_night' => AlarmState.armedNight,
          'triggered' => AlarmState.triggered,
          _ => s.alarmState,
        },
      ),
      DeviceKind.blind || DeviceKind.curtain || DeviceKind.garageDoor => state(
        s,
        raw: raw,
        coverState: CoverState.values.where((c) => c.name == raw).firstOrNull,
      ),
      DeviceKind.person => state(s, raw: raw, textValue: raw),
      final k when k.isSensor && double.tryParse(raw) == null => state(
        s,
        raw: raw,
        isActive: on,
      ),
      final k when double.tryParse(raw) != null && !k.isLight => state(
        s,
        raw: raw,
        numericValue: double.parse(raw),
      ),
      _ => state(s, raw: raw, isOn: on),
    }, available: !unavailable);
  }

  /// A device appeared or changed altogether.
  void update(SmartHomeDevice device) {
    _devices[device.id] = device;
    _controller.add(current);
  }

  void remove(String id) {
    _devices.remove(_full(id));
    _controller.add(current);
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    sent.add((device.id, command));
    final next = answer(device.state, command);
    if (next != null) update(_with(device, state: next));
  }

  /// How a device's state follows [command]; `null` when it does not.
  static DeviceState? answer(
    DeviceState s,
    DeviceCommand command,
  ) => switch (command) {
    TurnOn() => _power(s, true),
    TurnOff() => _power(s, false),
    Toggle() => _power(s, !(s.isOn ?? false)),
    SetBrightness(:final percent) => state(
      s,
      raw: percent > 0 ? 'on' : 'off',
      isOn: percent > 0,
      brightnessPercent: percent,
    ),
    SetColorTemperature(:final kelvin) => state(
      s,
      raw: 'on',
      isOn: true,
      colorTemperatureKelvin: kelvin,
    ),
    SetRgbColor(:final color) => state(s, raw: 'on', isOn: true, rgb: color),
    SetTargetTemperature(:final temperature) => state(
      s,
      targetTemperature: temperature,
    ),
    SetHvacMode(:final mode) => state(s, raw: mode, hvacMode: mode),
    SetFanMode(:final mode) => state(s, fanMode: mode),
    SetPresetMode(:final mode) => state(s, presetMode: mode),
    SetFanSpeed(:final percent) => state(
      s,
      raw: percent > 0 ? 'on' : 'off',
      isOn: percent > 0,
      percentage: percent,
    ),
    SetOscillation(:final on) => state(s, oscillating: on),
    SetTargetHumidity(:final humidity) => state(s, targetHumidity: humidity),
    MediaPlayPause() => state(
      s,
      raw: s.raw == 'playing' ? 'paused' : 'playing',
    ),
    MediaSeek(:final position) => state(s, mediaPosition: position),
    SetVolume(:final percent) => state(s, volumePercent: percent),
    SetMute(:final muted) => state(s, isMuted: muted),
    SelectSource(:final source) => state(s, source: source),
    SelectSoundMode(:final mode) => state(s, soundMode: mode),
    SetShuffle(:final on) => state(s, shuffle: on),
    SetRepeat(:final mode) => state(s, repeat: mode),
    OpenCover() => state(
      s,
      raw: 'open',
      coverState: CoverState.open,
      position: 100,
    ),
    CloseCover() => state(
      s,
      raw: 'closed',
      coverState: CoverState.closed,
      position: 0,
    ),
    SetCoverPosition(:final percent) => state(
      s,
      raw: percent == 0 ? 'closed' : 'open',
      coverState: percent == 0 ? CoverState.closed : CoverState.open,
      position: percent,
    ),
    LockDevice() => state(s, raw: 'locked', lockState: DoorLockState.locked),
    UnlockDevice() => state(
      s,
      raw: 'unlocked',
      lockState: DoorLockState.unlocked,
    ),
    ArmAlarm(:final mode) => state(
      s,
      raw: 'armed_$mode',
      alarmState: switch (mode) {
        'home' => AlarmState.armedHome,
        'night' => AlarmState.armedNight,
        _ => AlarmState.armedAway,
      },
    ),
    // The alarm's code is 1234; a wrong one changes nothing.
    DisarmAlarm(:final code) when code != null && code != '1234' => null,
    DisarmAlarm() => state(s, raw: 'disarmed', alarmState: AlarmState.disarmed),
    VacuumStart() => state(s, raw: 'cleaning'),
    VacuumPause() => state(s, raw: 'paused'),
    VacuumReturnHome() => state(s, raw: 'returning'),
    SelectOption(:final option) => state(s, raw: option, textValue: option),
    SetNumber(:final value) => state(s, raw: '$value', numericValue: value),
    _ => null,
  };

  static DeviceState _power(DeviceState s, bool on) =>
      state(s, raw: on ? 'on' : 'off', isOn: on);

  @override
  Future<void> dispose() => _controller.close();
}

/// [d] under another name.
SmartHomeDevice renamed(SmartHomeDevice d, String name) => _with(d, name: name);

SmartHomeDevice _with(
  SmartHomeDevice d, {
  String? name,
  DeviceState? state,
  bool? available,
  DateTime? lastChanged,
}) => SmartHomeDevice(
  id: d.id,
  sourceId: d.sourceId,
  deviceId: d.deviceId,
  name: name ?? d.name,
  roomId: d.roomId,
  kind: d.kind,
  protocol: d.protocol,
  manufacturer: d.manufacturer,
  model: d.model,
  available: available ?? d.available,
  capabilities: d.capabilities,
  state: state ?? d.state,
  limits: d.limits,
  metadata: lastChanged == null
      ? d.metadata
      : DeviceMetadata(
          batteryPercent: d.metadata.batteryPercent,
          haDeviceClass: d.metadata.haDeviceClass,
          lastChanged: lastChanged,
        ),
  isAuxiliary: d.isAuxiliary,
);

/// [s] with some values changed.
DeviceState state(
  DeviceState s, {
  String? raw,
  bool? isOn,
  int? brightnessPercent,
  int? colorTemperatureKelvin,
  RgbColor? rgb,
  double? currentTemperature,
  double? targetTemperature,
  String? hvacMode,
  String? hvacAction,
  String? fanMode,
  String? presetMode,
  double? currentHumidity,
  double? targetHumidity,
  CoverState? coverState,
  int? position,
  DoorLockState? lockState,
  AlarmState? alarmState,
  bool? isActive,
  double? numericValue,
  String? textValue,
  int? volumePercent,
  bool? isMuted,
  String? source,
  String? mediaTitle,
  Duration? mediaPosition,
  bool? shuffle,
  String? repeat,
  String? soundMode,
  int? percentage,
  bool? oscillating,
}) => DeviceState(
  raw: raw ?? s.raw,
  isOn: isOn ?? s.isOn,
  brightnessPercent: brightnessPercent ?? s.brightnessPercent,
  colorTemperatureKelvin: colorTemperatureKelvin ?? s.colorTemperatureKelvin,
  rgb: rgb ?? s.rgb,
  currentTemperature: currentTemperature ?? s.currentTemperature,
  targetTemperature: targetTemperature ?? s.targetTemperature,
  targetTemperatureLow: s.targetTemperatureLow,
  targetTemperatureHigh: s.targetTemperatureHigh,
  hvacMode: hvacMode ?? s.hvacMode,
  hvacAction: hvacAction ?? s.hvacAction,
  fanMode: fanMode ?? s.fanMode,
  swingMode: s.swingMode,
  presetMode: presetMode ?? s.presetMode,
  currentHumidity: currentHumidity ?? s.currentHumidity,
  targetHumidity: targetHumidity ?? s.targetHumidity,
  coverState: coverState ?? s.coverState,
  position: position ?? s.position,
  tiltPosition: s.tiltPosition,
  lockState: lockState ?? s.lockState,
  alarmState: alarmState ?? s.alarmState,
  isActive: isActive ?? s.isActive,
  numericValue: numericValue ?? s.numericValue,
  textValue: textValue ?? s.textValue,
  unit: s.unit,
  volumePercent: volumePercent ?? s.volumePercent,
  isMuted: isMuted ?? s.isMuted,
  source: source ?? s.source,
  mediaTitle: mediaTitle ?? s.mediaTitle,
  mediaArtist: s.mediaArtist,
  mediaAlbum: s.mediaAlbum,
  mediaDuration: s.mediaDuration,
  mediaPosition: mediaPosition ?? s.mediaPosition,
  mediaPositionUpdatedAt: mediaPosition != null
      ? DateTime.now()
      : s.mediaPositionUpdatedAt,
  shuffle: shuffle ?? s.shuffle,
  repeat: repeat ?? s.repeat,
  soundMode: soundMode ?? s.soundMode,
  lastTriggered: s.lastTriggered,
  windSpeed: s.windSpeed,
  windSpeedUnit: s.windSpeedUnit,
  percentage: percentage ?? s.percentage,
  oscillating: oscillating ?? s.oscillating,
);

/// One device of the fixture's house.
SmartHomeDevice fixtureDevice(
  String id, {
  required String name,
  required DeviceKind kind,
  Set<Capability> capabilities = const {},
  DeviceState state = const DeviceState(raw: 'unknown'),
  String? roomId,
  bool available = true,
  DeviceLimits limits = DeviceLimits.none,
  DeviceMetadata metadata = const DeviceMetadata(),
  String? manufacturer,
  String? model,
  DeviceProtocol protocol = DeviceProtocol.wifi,
  String? deviceId,
}) => SmartHomeDevice(
  id: 'fx:$id',
  sourceId: id,
  deviceId: deviceId,
  name: name,
  roomId: roomId,
  kind: kind,
  protocol: protocol,
  manufacturer: manufacturer,
  model: model,
  available: available,
  capabilities: capabilities,
  state: state,
  limits: limits,
  metadata: metadata,
);

List<SmartHomeDevice> fixtureDevices(DateTime now) => [
  fixtureDevice(
    'light.hallway',
    name: 'Hodnik',
    kind: DeviceKind.light,
    capabilities: const {Capability.power},
    state: const DeviceState(raw: 'off', isOn: false),
    roomId: 'hallway',
    manufacturer: 'IKEA',
    model: 'LED2101G4',
  ),
  fixtureDevice(
    'light.living_room_main',
    name: 'Dnevna soba – glavno svetlo',
    kind: DeviceKind.dimmableLight,
    capabilities: const {
      Capability.power,
      Capability.brightness,
      Capability.colorTemperature,
    },
    state: const DeviceState(
      raw: 'on',
      isOn: true,
      brightnessPercent: 75,
      colorTemperatureKelvin: 3200,
    ),
    limits: const DeviceLimits(
      minColorTemperatureKelvin: 2200,
      maxColorTemperatureKelvin: 6500,
    ),
    roomId: 'living_room',
    manufacturer: 'Signify',
    protocol: DeviceProtocol.zigbee,
  ),
  fixtureDevice(
    'light.living_room_ambient',
    name: 'Dnevna soba – ambijent',
    kind: DeviceKind.rgbLight,
    capabilities: const {
      Capability.power,
      Capability.brightness,
      Capability.rgb,
    },
    state: const DeviceState(
      raw: 'on',
      isOn: true,
      brightnessPercent: 50,
      rgb: RgbColor(255, 140, 40),
    ),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'switch.coffee_machine',
    name: 'Aparat za kafu',
    kind: DeviceKind.switchDevice,
    capabilities: const {Capability.power},
    state: const DeviceState(raw: 'off', isOn: false),
    roomId: 'kitchen',
    manufacturer: 'Shelly',
    model: 'Plus 1PM',
  ),
  fixtureDevice(
    'switch.washer_plug',
    name: 'Veš mašina utičnica',
    kind: DeviceKind.outlet,
    capabilities: const {Capability.power},
    state: const DeviceState(raw: 'on', isOn: true),
    roomId: 'kitchen',
    deviceId: 'd_washer',
  ),
  fixtureDevice(
    'sensor.washer_plug_power',
    name: 'Veš mašina snaga',
    kind: DeviceKind.powerMeter,
    state: const DeviceState(raw: '420', numericValue: 420, unit: 'W'),
    roomId: 'kitchen',
    deviceId: 'd_washer',
  ),
  fixtureDevice(
    'switch.tv_outlet',
    name: 'Utičnica TV',
    kind: DeviceKind.outlet,
    capabilities: const {Capability.power},
    state: const DeviceState(raw: 'on', isOn: true),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'sensor.living_room_temperature',
    name: 'Temperatura dnevna soba',
    kind: DeviceKind.temperatureSensor,
    capabilities: const {Capability.currentTemperature},
    state: const DeviceState(
      raw: '22.4',
      numericValue: 22.4,
      currentTemperature: 22.4,
      unit: '°C',
    ),
    roomId: 'living_room',
    deviceId: 'd_living_climate_sensor',
  ),
  fixtureDevice(
    'sensor.living_room_humidity',
    name: 'Vlažnost dnevna soba',
    kind: DeviceKind.humiditySensor,
    capabilities: const {Capability.humidity},
    state: const DeviceState(
      raw: '48',
      numericValue: 48,
      currentHumidity: 48,
      unit: '%',
    ),
    roomId: 'living_room',
    deviceId: 'd_living_climate_sensor',
  ),
  fixtureDevice(
    'binary_sensor.hallway_motion',
    name: 'Pokret hodnik',
    kind: DeviceKind.motionSensor,
    state: const DeviceState(raw: 'off', isActive: false),
    roomId: 'hallway',
  ),
  fixtureDevice(
    'binary_sensor.front_door',
    name: 'Ulazna vrata',
    kind: DeviceKind.contactSensor,
    state: const DeviceState(raw: 'off', isActive: false),
    roomId: 'hallway',
  ),
  fixtureDevice(
    'binary_sensor.bedroom_window',
    name: 'Prozor spavaća soba',
    kind: DeviceKind.contactSensor,
    state: const DeviceState(raw: 'off', isActive: false),
    roomId: 'bedroom',
    metadata: const DeviceMetadata(batteryPercent: 8),
  ),
  fixtureDevice(
    'binary_sensor.kitchen_smoke',
    name: 'Dim kuhinja',
    kind: DeviceKind.smokeSensor,
    state: const DeviceState(raw: 'off', isActive: false),
    roomId: 'kitchen',
  ),
  fixtureDevice(
    'sensor.bedroom_co2',
    name: 'CO2 spavaća soba',
    kind: DeviceKind.airQualitySensor,
    state: const DeviceState(raw: '1350', numericValue: 1350, unit: 'ppm'),
    roomId: 'bedroom',
    metadata: const DeviceMetadata(haDeviceClass: 'carbon_dioxide'),
  ),
  fixtureDevice(
    'climate.living_room',
    name: 'Klima dnevna soba',
    kind: DeviceKind.climate,
    capabilities: const {
      Capability.power,
      Capability.targetTemperature,
      Capability.currentTemperature,
      Capability.hvacMode,
      Capability.fanMode,
      Capability.presetMode,
    },
    state: const DeviceState(
      raw: 'heat',
      isOn: true,
      currentTemperature: 22.4,
      targetTemperature: 23,
      hvacMode: 'heat',
      hvacAction: 'heating',
      fanMode: 'auto',
      presetMode: 'home',
    ),
    limits: const DeviceLimits(
      minTemperature: 16,
      maxTemperature: 30,
      temperatureStep: 0.5,
      hvacModes: ['off', 'heat', 'cool', 'auto'],
      fanModes: ['auto', 'low', 'high'],
      presetModes: ['none', 'home', 'sleep', 'away', 'eco'],
    ),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'cover.living_room_blinds',
    name: 'Roletne dnevna soba',
    kind: DeviceKind.blind,
    capabilities: const {
      Capability.open,
      Capability.close,
      Capability.stop,
      Capability.position,
    },
    state: const DeviceState(
      raw: 'open',
      coverState: CoverState.open,
      position: 100,
    ),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'cover.living_room_curtain',
    name: 'Zavesa dnevna soba',
    kind: DeviceKind.curtain,
    capabilities: const {
      Capability.open,
      Capability.close,
      Capability.stop,
      Capability.position,
    },
    state: const DeviceState(
      raw: 'closed',
      coverState: CoverState.closed,
      position: 0,
    ),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'cover.garage',
    name: 'Garažna vrata',
    kind: DeviceKind.garageDoor,
    capabilities: const {Capability.open, Capability.close},
    state: const DeviceState(raw: 'closed', coverState: CoverState.closed),
    roomId: 'garage',
  ),
  fixtureDevice(
    'fan.bedroom_fan',
    name: 'Ventilator spavaća soba',
    kind: DeviceKind.fan,
    capabilities: const {
      Capability.power,
      Capability.fanSpeed,
      Capability.oscillate,
    },
    state: const DeviceState(
      raw: 'off',
      isOn: false,
      percentage: 0,
      oscillating: false,
    ),
    limits: const DeviceLimits(percentageStep: 100 / 3),
    roomId: 'bedroom',
  ),
  fixtureDevice(
    'vacuum.robot',
    name: 'Robot usisivač',
    kind: DeviceKind.vacuum,
    capabilities: const {
      Capability.vacuumStart,
      Capability.vacuumPause,
      Capability.vacuumReturnHome,
    },
    state: const DeviceState(raw: 'docked'),
    metadata: const DeviceMetadata(batteryPercent: 100),
  ),
  fixtureDevice(
    'humidifier.bedroom',
    name: 'Ovlaživač',
    kind: DeviceKind.humidifier,
    capabilities: const {Capability.power, Capability.targetHumidity},
    state: const DeviceState(
      raw: 'on',
      isOn: true,
      targetHumidity: 50,
      currentHumidity: 42,
    ),
    limits: const DeviceLimits(minHumidity: 30, maxHumidity: 80),
    roomId: 'bedroom',
  ),
  fixtureDevice(
    'input_select.house_mode',
    name: 'Režim kuće',
    kind: DeviceKind.select,
    capabilities: const {Capability.selectOption},
    state: const DeviceState(raw: 'Kod kuće', textValue: 'Kod kuće'),
    limits: const DeviceLimits(options: ['Kod kuće', 'Odsutni', 'Noć']),
  ),
  fixtureDevice(
    'input_number.night_temperature',
    name: 'Noćna temperatura',
    kind: DeviceKind.number,
    capabilities: const {Capability.numberValue},
    state: const DeviceState(raw: '19.0', numericValue: 19, unit: '°C'),
    limits: const DeviceLimits(minValue: 15, maxValue: 25, valueStep: 0.5),
  ),
  fixtureDevice(
    'alarm_control_panel.home_alarm',
    name: 'Alarm',
    kind: DeviceKind.alarm,
    capabilities: const {Capability.arm, Capability.disarm},
    state: const DeviceState(raw: 'disarmed', alarmState: AlarmState.disarmed),
    limits: const DeviceLimits(
      alarmArmModes: ['home', 'away', 'night'],
      alarmCodeFormat: 'number',
    ),
  ),
  fixtureDevice(
    'lock.front_door',
    name: 'Brava ulazna vrata',
    kind: DeviceKind.lock,
    capabilities: const {Capability.lock, Capability.unlock},
    state: const DeviceState(raw: 'locked', lockState: DoorLockState.locked),
    roomId: 'hallway',
    manufacturer: 'Yale',
  ),
  fixtureDevice(
    'media_player.living_room_speaker',
    name: 'Zvučnik dnevna soba',
    kind: DeviceKind.speaker,
    capabilities: const {
      Capability.power,
      Capability.mediaPlay,
      Capability.mediaPause,
      Capability.mediaNext,
      Capability.mediaPrevious,
      Capability.mediaSeek,
      Capability.volume,
      Capability.mute,
      Capability.sourceSelection,
      Capability.shuffle,
      Capability.repeat,
    },
    state: DeviceState(
      raw: 'playing',
      isOn: true,
      mediaTitle: 'Kafa i kiša',
      mediaArtist: 'Demo bend',
      mediaAlbum: 'Jesenje jutro',
      volumePercent: 35,
      isMuted: false,
      source: 'Radio',
      mediaDuration: const Duration(seconds: 215),
      mediaPosition: const Duration(seconds: 62),
      mediaPositionUpdatedAt: now,
      shuffle: false,
      repeat: 'off',
    ),
    limits: const DeviceLimits(sources: ['Radio', 'Bluetooth', 'AirPlay']),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'media_player.living_room_tv',
    name: 'Televizor',
    kind: DeviceKind.television,
    capabilities: const {
      Capability.power,
      Capability.mediaPlay,
      Capability.mediaPause,
      Capability.volume,
      Capability.mute,
      Capability.sourceSelection,
      Capability.soundMode,
      Capability.tvKeys,
    },
    state: const DeviceState(
      raw: 'off',
      isOn: false,
      isMuted: false,
      soundMode: 'Standard',
    ),
    limits: const DeviceLimits(
      sources: ['TV', 'HDMI 1', 'HDMI 2'],
      soundModes: ['Standard', 'Film', 'Muzika'],
      tvKeys: {...TvKey.values},
    ),
    roomId: 'living_room',
  ),
  fixtureDevice(
    'sensor.house_power',
    name: 'Trenutna snaga',
    kind: DeviceKind.powerMeter,
    state: const DeviceState(raw: '742', numericValue: 742, unit: 'W'),
  ),
  fixtureDevice(
    'switch.garage_heater',
    name: 'Grejalica garaža',
    kind: DeviceKind.switchDevice,
    capabilities: const {Capability.power},
    state: const DeviceState(raw: 'unavailable'),
    available: false,
    roomId: 'garage',
  ),
  fixtureDevice(
    'person.marko',
    name: 'Marko',
    kind: DeviceKind.person,
    state: const DeviceState(raw: 'home', textValue: 'home'),
  ),
  fixtureDevice(
    'person.ana',
    name: 'Ana',
    kind: DeviceKind.person,
    state: const DeviceState(raw: 'not_home', textValue: 'not_home'),
  ),
];
