import 'package:flutter/foundation.dart';

import 'capability.dart';
import 'device_kind.dart';
import 'tv_key.dart';

export 'tv_key.dart';

enum CoverState { open, closed, opening, closing }

enum DoorLockState {
  locked,
  unlocked,
  locking,
  unlocking,
  jammed,
  open,
  opening,
}

enum AlarmState {
  disarmed,
  armedHome,
  armedAway,
  armedNight,
  armedVacation,
  armedCustomBypass,
  arming,
  disarming,
  pending,
  triggered,
}

@immutable
class RgbColor {
  const RgbColor(this.red, this.green, this.blue);

  final int red;
  final int green;
  final int blue;

  @override
  bool operator ==(Object other) =>
      other is RgbColor &&
      other.red == red &&
      other.green == green &&
      other.blue == blue;

  @override
  int get hashCode => Object.hash(red, green, blue);

  @override
  String toString() => 'rgb($red, $green, $blue)';
}

/// Current values, normalised to app units (percent 0–100, Kelvin, …).
/// Fields irrelevant to a device stay `null`; `null` also means "not
/// reported", which the UI must show as unknown rather than as zero.
@immutable
class DeviceState {
  const DeviceState({
    required this.raw,
    this.isOn,
    this.brightnessPercent,
    this.colorTemperatureKelvin,
    this.rgb,
    this.currentTemperature,
    this.targetTemperature,
    this.targetTemperatureLow,
    this.targetTemperatureHigh,
    this.hvacMode,
    this.hvacAction,
    this.fanMode,
    this.swingMode,
    this.presetMode,
    this.currentHumidity,
    this.targetHumidity,
    this.coverState,
    this.position,
    this.tiltPosition,
    this.lockState,
    this.alarmState,
    this.isActive,
    this.numericValue,
    this.textValue,
    this.unit,
    this.volumePercent,
    this.isMuted,
    this.source,
    this.mediaTitle,
    this.mediaArtist,
    this.mediaAlbum,
    this.mediaDuration,
    this.mediaPosition,
    this.mediaPositionUpdatedAt,
    this.shuffle,
    this.repeat,
    this.soundMode,
    this.lastTriggered,
    this.windSpeed,
    this.windSpeedUnit,
    this.percentage,
    this.oscillating,
  });

  /// Home Assistant's state string, kept for diagnostics.
  final String raw;

  final bool? isOn;
  final int? brightnessPercent;
  final int? colorTemperatureKelvin;
  final RgbColor? rgb;

  final double? currentTemperature;
  final double? targetTemperature;
  final double? targetTemperatureLow;
  final double? targetTemperatureHigh;
  final String? hvacMode;

  /// What the device is doing right now (`heating`, `cooling`, `idle`, …).
  final String? hvacAction;
  final String? fanMode;
  final String? swingMode;
  final String? presetMode;
  final double? currentHumidity;
  final double? targetHumidity;

  final CoverState? coverState;

  /// 0 = closed, 100 = fully open.
  final int? position;
  final int? tiltPosition;

  final DoorLockState? lockState;
  final AlarmState? alarmState;

  /// Binary sensors: `true` = detected / open / wet / …
  final bool? isActive;

  /// Numeric sensor reading in [unit].
  final double? numericValue;

  /// Non-numeric sensor reading (e.g. an enum sensor).
  final String? textValue;
  final String? unit;

  final int? volumePercent;
  final bool? isMuted;
  final String? source;
  final String? mediaTitle;

  /// Artist, or the album / channel / app when there is no artist.
  final String? mediaArtist;
  final String? mediaAlbum;

  /// Length of what plays, and where it was at [mediaPositionUpdatedAt]
  /// (Home Assistant does not stream the position; it moves on from there
  /// while playing).
  final Duration? mediaDuration;
  final Duration? mediaPosition;
  final DateTime? mediaPositionUpdatedAt;
  final bool? shuffle;

  /// Media player's sound mode (`Movie`, `Music`…), one of
  /// [DeviceLimits.soundModes].
  final String? soundMode;

  /// `off`, `all` or `one`.
  final String? repeat;

  /// The position now, counting on from the last report while playing.
  Duration? positionAt(DateTime now) {
    final p = mediaPosition;
    if (p == null) return null;
    final at = mediaPositionUpdatedAt;
    var current = raw == 'playing' && at != null ? p + now.difference(at) : p;
    final d = mediaDuration;
    if (d != null && current > d) current = d;
    return current.isNegative ? Duration.zero : current;
  }

  /// Automations and scripts.
  final DateTime? lastTriggered;

  /// Weather entities.
  final double? windSpeed;
  final String? windSpeedUnit;

  /// Fan speed 0–100.
  final int? percentage;
  final bool? oscillating;
}

/// Allowed ranges and options, so controls never offer invalid values.
@immutable
class DeviceLimits {
  const DeviceLimits({
    this.minColorTemperatureKelvin,
    this.maxColorTemperatureKelvin,
    this.minTemperature,
    this.maxTemperature,
    this.temperatureStep,
    this.minHumidity,
    this.maxHumidity,
    this.hvacModes = const [],
    this.fanModes = const [],
    this.swingModes = const [],
    this.presetModes = const [],
    this.sources = const [],
    this.alarmArmModes = const [],
    this.alarmCodeFormat,
    this.alarmCodeArmRequired = false,
    this.options = const [],
    this.minValue,
    this.maxValue,
    this.valueStep,
    this.percentageStep,
    this.todoFeatures = 0,
    this.soundModes = const [],
    this.tvKeys = const {},
  });

  static const DeviceLimits none = DeviceLimits();

  final int? minColorTemperatureKelvin;
  final int? maxColorTemperatureKelvin;
  final double? minTemperature;
  final double? maxTemperature;
  final double? temperatureStep;
  final double? minHumidity;
  final double? maxHumidity;
  final List<String> hvacModes;
  final List<String> fanModes;
  final List<String> swingModes;
  final List<String> presetModes;
  final List<String> sources;

  /// Arm modes the alarm panel offers (`home`, `away`, `night`,
  /// `vacation`, `custom_bypass`).
  final List<String> alarmArmModes;

  /// `number`, `text` or `null` (no code).
  final String? alarmCodeFormat;
  final bool alarmCodeArmRequired;

  /// Choices of a select.
  final List<String> options;

  /// Range of a number entity.
  final double? minValue;
  final double? maxValue;
  final double? valueStep;

  /// Fan speed step (e.g. 33.33 for a 3-speed fan).
  final double? percentageStep;

  /// Home Assistant `TodoListEntityFeature` flags of a to-do list:
  /// 1 create, 2 delete, 4 update items.
  final int todoFeatures;

  /// Sound modes of a media player.
  final List<String> soundModes;

  /// Remote-control keys a TV (or its remote entity) takes.
  final Set<TvKey> tvKeys;
}

@immutable
class DeviceMetadata {
  const DeviceMetadata({
    this.batteryPercent,
    this.batteryLow,
    this.signalStrength,
    this.signalUnit,
    this.haDeviceClass,
    this.lastChanged,
    this.lastUpdated,
    this.picturePath,
    this.configId,
    this.integration,
  });

  /// From a battery sensor of the same physical device, if any.
  final int? batteryPercent;

  /// From a `battery` binary sensor of the same physical device, if any.
  final bool? batteryLow;
  final double? signalStrength;
  final String? signalUnit;

  /// Home Assistant `device_class` attribute, kept for icon selection.
  final String? haDeviceClass;
  final DateTime? lastChanged;
  final DateTime? lastUpdated;

  /// `entity_picture` when it is a path on the Home Assistant server
  /// (`/api/...`). External URLs are dropped: the app never sends the
  /// token to, or loads pictures from, other hosts.
  final String? picturePath;

  /// Id of a UI-managed automation/script (attribute `id`), needed to
  /// delete it.
  final String? configId;

  /// Home Assistant integration that provides the entity (`webostv`,
  /// `samsungtv`…), where its services differ by integration.
  final String? integration;
}

/// The protocol-independent device model the whole UI works with.
@immutable
class SmartHomeDevice {
  const SmartHomeDevice({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.kind,
    required this.available,
    required this.capabilities,
    required this.state,
    this.deviceId,
    this.roomId,
    this.protocol = DeviceProtocol.unknown,
    this.manufacturer,
    this.model,
    this.limits = DeviceLimits.none,
    this.metadata = const DeviceMetadata(),
    this.isAuxiliary = false,
  });

  /// Stable app id. Equal to [sourceId] for Home Assistant entities.
  final String id;

  /// Id in the source system (Home Assistant `entity_id`).
  final String sourceId;

  /// Home Assistant device-registry id, shared by entities of one device.
  final String? deviceId;
  final String name;
  final String? roomId;
  final DeviceKind kind;
  final DeviceProtocol protocol;
  final String? manufacturer;
  final String? model;

  /// `false` when Home Assistant reports the entity as `unavailable`.
  final bool available;
  final Set<Capability> capabilities;
  final DeviceState state;
  final DeviceLimits limits;
  final DeviceMetadata metadata;

  /// Hidden, configuration or diagnostic entities. Kept (they feed
  /// metadata such as battery) but not shown in normal lists.
  final bool isAuxiliary;

  bool supports(Capability capability) => capabilities.contains(capability);

  /// Low battery: ≤ 15 % or a battery-low binary sensor is on.
  bool get hasLowBattery =>
      metadata.batteryLow == true ||
      (metadata.batteryPercent != null && metadata.batteryPercent! <= 15);

  @override
  String toString() =>
      'SmartHomeDevice($id, ${kind.name}, available: $available)';
}

/// An area / room.
@immutable
class Room {
  const Room({
    required this.id,
    required this.name,
    this.icon,
    this.picture,
    this.floorName,
    this.floorLevel,
  });

  /// Floor the room is on (HA floor registry), if set.
  final String? floorName;
  final int? floorLevel;

  final String id;
  final String name;

  /// Material Design Icons name from Home Assistant, e.g. `mdi:sofa`.
  final String? icon;
  final String? picture;

  @override
  bool operator ==(Object other) =>
      other is Room &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.picture == picture &&
      other.floorName == floorName &&
      other.floorLevel == floorLevel;

  @override
  int get hashCode =>
      Object.hash(id, name, icon, picture, floorName, floorLevel);
}
