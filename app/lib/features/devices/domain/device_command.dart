import 'package:flutter/foundation.dart';

import 'capability.dart';
import 'device_kind.dart';
import 'smart_home_device.dart';

/// A protocol-independent instruction for one device.
///
/// Each command names the capability it needs ([requiredCapability]); the
/// command service refuses commands the device does not declare.
@immutable
sealed class DeviceCommand {
  const DeviceCommand();

  Capability get requiredCapability;

  /// Commands with physical security impact (unlocking doors, disarming an
  /// alarm, opening a garage) must be confirmed by the user first.
  bool isCritical(SmartHomeDevice device) => false;
}

final class TurnOn extends DeviceCommand {
  const TurnOn();
  @override
  Capability get requiredCapability => Capability.power;
}

final class TurnOff extends DeviceCommand {
  const TurnOff();
  @override
  Capability get requiredCapability => Capability.power;
}

final class Toggle extends DeviceCommand {
  const Toggle();
  @override
  Capability get requiredCapability => Capability.power;
}

final class SetBrightness extends DeviceCommand {
  const SetBrightness(this.percent) : assert(percent >= 0 && percent <= 100);
  final int percent;
  @override
  Capability get requiredCapability => Capability.brightness;
}

final class SetColorTemperature extends DeviceCommand {
  const SetColorTemperature(this.kelvin);
  final int kelvin;
  @override
  Capability get requiredCapability => Capability.colorTemperature;
}

final class SetRgbColor extends DeviceCommand {
  const SetRgbColor(this.color);
  final RgbColor color;
  @override
  Capability get requiredCapability => Capability.rgb;
}

final class SetTargetTemperature extends DeviceCommand {
  const SetTargetTemperature(this.temperature);
  final double temperature;
  @override
  Capability get requiredCapability => Capability.targetTemperature;
}

final class SetHvacMode extends DeviceCommand {
  const SetHvacMode(this.mode);
  final String mode;
  @override
  Capability get requiredCapability => Capability.hvacMode;
}

final class SetFanMode extends DeviceCommand {
  const SetFanMode(this.mode);
  final String mode;
  @override
  Capability get requiredCapability => Capability.fanMode;
}

/// Climate/fan/humidifier preset, e.g. `home`, `sleep`, `eco`.
final class SetPresetMode extends DeviceCommand {
  const SetPresetMode(this.mode);
  final String mode;
  @override
  Capability get requiredCapability => Capability.presetMode;
}

/// Toggle between playing and paused.
final class MediaPlayPause extends DeviceCommand {
  const MediaPlayPause();
  @override
  Capability get requiredCapability => Capability.mediaPause;
}

final class MediaNext extends DeviceCommand {
  const MediaNext();
  @override
  Capability get requiredCapability => Capability.mediaNext;
}

final class MediaPrevious extends DeviceCommand {
  const MediaPrevious();
  @override
  Capability get requiredCapability => Capability.mediaPrevious;
}

/// Jump to [position] in what is playing.
final class MediaSeek extends DeviceCommand {
  const MediaSeek(this.position);
  final Duration position;
  @override
  Capability get requiredCapability => Capability.mediaSeek;
}

final class SetShuffle extends DeviceCommand {
  const SetShuffle(this.on);
  final bool on;
  @override
  Capability get requiredCapability => Capability.shuffle;
}

/// `off`, `all` or `one`.
final class SetRepeat extends DeviceCommand {
  const SetRepeat(this.mode);
  final String mode;
  @override
  Capability get requiredCapability => Capability.repeat;
}

/// Input / app of a media player (from its source list).
final class SelectSource extends DeviceCommand {
  const SelectSource(this.source);
  final String source;
  @override
  Capability get requiredCapability => Capability.sourceSelection;
}

final class SetFanSpeed extends DeviceCommand {
  const SetFanSpeed(this.percent) : assert(percent >= 0 && percent <= 100);
  final int percent;
  @override
  Capability get requiredCapability => Capability.fanSpeed;
}

final class SetOscillation extends DeviceCommand {
  const SetOscillation(this.on);
  final bool on;
  @override
  Capability get requiredCapability => Capability.oscillate;
}

final class SetTargetHumidity extends DeviceCommand {
  const SetTargetHumidity(this.humidity);
  final double humidity;
  @override
  Capability get requiredCapability => Capability.targetHumidity;
}

final class VacuumStart extends DeviceCommand {
  const VacuumStart();
  @override
  Capability get requiredCapability => Capability.vacuumStart;
}

final class VacuumPause extends DeviceCommand {
  const VacuumPause();
  @override
  Capability get requiredCapability => Capability.vacuumPause;
}

final class VacuumReturnHome extends DeviceCommand {
  const VacuumReturnHome();
  @override
  Capability get requiredCapability => Capability.vacuumReturnHome;
}

final class SelectOption extends DeviceCommand {
  const SelectOption(this.option);
  final String option;
  @override
  Capability get requiredCapability => Capability.selectOption;
}

final class SetNumber extends DeviceCommand {
  const SetNumber(this.value);
  final double value;
  @override
  Capability get requiredCapability => Capability.numberValue;
}

final class SetVolume extends DeviceCommand {
  const SetVolume(this.percent) : assert(percent >= 0 && percent <= 100);
  final int percent;
  @override
  Capability get requiredCapability => Capability.volume;
}

/// Sound on or off ([muted]).
final class SetMute extends DeviceCommand {
  const SetMute(this.muted);
  final bool muted;
  @override
  Capability get requiredCapability => Capability.mute;
}

/// Volume one step up ([up]) or down.
final class StepVolume extends DeviceCommand {
  const StepVolume({required this.up});
  final bool up;
  @override
  Capability get requiredCapability => Capability.volumeStep;
}

final class SelectSoundMode extends DeviceCommand {
  const SelectSoundMode(this.mode);
  final String mode;
  @override
  Capability get requiredCapability => Capability.soundMode;
}

/// A key of the TV remote.
final class PressTvKey extends DeviceCommand {
  const PressTvKey(this.key);
  final TvKey key;
  @override
  Capability get requiredCapability => Capability.tvKeys;
}

final class OpenCover extends DeviceCommand {
  const OpenCover();
  @override
  Capability get requiredCapability => Capability.open;
  @override
  bool isCritical(SmartHomeDevice device) =>
      device.kind == DeviceKind.garageDoor;
}

final class CloseCover extends DeviceCommand {
  const CloseCover();
  @override
  Capability get requiredCapability => Capability.close;
}

final class StopCover extends DeviceCommand {
  const StopCover();
  @override
  Capability get requiredCapability => Capability.stop;
}

final class SetCoverPosition extends DeviceCommand {
  const SetCoverPosition(this.percent) : assert(percent >= 0 && percent <= 100);
  final int percent;
  @override
  Capability get requiredCapability => Capability.position;
  @override
  bool isCritical(SmartHomeDevice device) =>
      device.kind == DeviceKind.garageDoor && percent > 0;
}

final class LockDevice extends DeviceCommand {
  const LockDevice();
  @override
  Capability get requiredCapability => Capability.lock;
}

final class UnlockDevice extends DeviceCommand {
  const UnlockDevice();
  @override
  Capability get requiredCapability => Capability.unlock;
  @override
  bool isCritical(SmartHomeDevice device) => true;
}

/// Arms the alarm in one of the panel's [DeviceLimits.alarmArmModes].
final class ArmAlarm extends DeviceCommand {
  const ArmAlarm(this.mode, {this.code});

  final String mode;

  /// Alarm code, if arming requires one. Never logged.
  final String? code;
  @override
  Capability get requiredCapability => Capability.arm;
}

final class DisarmAlarm extends DeviceCommand {
  const DisarmAlarm({this.code});

  /// Alarm code, if the panel requires one. Never logged.
  final String? code;
  @override
  Capability get requiredCapability => Capability.disarm;
  @override
  bool isCritical(SmartHomeDevice device) => true;
}

/// Runs a scene/script, presses a button or triggers an automation.
final class Activate extends DeviceCommand {
  const Activate();
  @override
  Capability get requiredCapability => Capability.trigger;
}
