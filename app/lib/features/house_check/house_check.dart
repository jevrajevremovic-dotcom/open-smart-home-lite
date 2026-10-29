import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';

/// Before leaving the house, or before going to bed.
enum HouseCheckMode {
  leaving,
  night;

  /// Evenings and nights suggest the bedtime check.
  static HouseCheckMode forTime(DateTime now) =>
      now.hour >= 20 || now.hour < 5 ? night : leaving;

  static HouseCheckMode? tryParse(String? name) =>
      values.where((m) => m.name == name).firstOrNull;
}

/// Why a device is on the list.
enum HouseCheckProblem {
  lightOn,
  mediaOn,
  climateOn,
  unlocked,
  garageOpen,
  opened,
  alarmOff,
}

/// One thing to look at, with the command that fixes it when the app can.
@immutable
class HouseCheckItem {
  const HouseCheckItem(this.device, this.problem, this.fix);

  final SmartHomeDevice device;
  final HouseCheckProblem problem;

  /// `null`: the app cannot fix it (a window), or it needs the user (an
  /// alarm code); the device's own screen is offered instead.
  final DeviceCommand? fix;

  @override
  bool operator ==(Object other) =>
      other is HouseCheckItem &&
      other.device == device &&
      other.problem == problem &&
      other.fix.runtimeType == fix.runtimeType;

  @override
  int get hashCode => Object.hash(device, problem, fix.runtimeType);
}

/// What is still on, open or unlocked for [mode], most important first.
/// Only uses the state Home Assistant reports; nothing is guessed.
List<HouseCheckItem> houseCheck(
  Iterable<SmartHomeDevice> devices,
  HouseCheckMode mode,
) {
  final items = <HouseCheckItem>[];
  DeviceCommand? when(SmartHomeDevice d, Capability c, DeviceCommand cmd) =>
      d.supports(c) ? cmd : null;

  for (final d in devices) {
    if (!d.available || d.isAuxiliary) continue;
    final s = d.state;
    switch (d.kind) {
      case DeviceKind.lock:
        if (s.lockState == DoorLockState.unlocked ||
            s.lockState == DoorLockState.open) {
          items.add(
            HouseCheckItem(
              d,
              HouseCheckProblem.unlocked,
              when(d, Capability.lock, const LockDevice()),
            ),
          );
        }
      case DeviceKind.garageDoor:
        if (s.coverState != null && s.coverState != CoverState.closed) {
          items.add(
            HouseCheckItem(
              d,
              HouseCheckProblem.garageOpen,
              when(d, Capability.close, const CloseCover()),
            ),
          );
        }
      case DeviceKind.contactSensor:
        if (s.isActive == true) {
          items.add(HouseCheckItem(d, HouseCheckProblem.opened, null));
        }
      case DeviceKind.alarm:
        if (s.alarmState == AlarmState.disarmed && d.supports(Capability.arm)) {
          items.add(HouseCheckItem(d, HouseCheckProblem.alarmOff, null));
        }
      case DeviceKind.mediaPlayer ||
          DeviceKind.speaker ||
          DeviceKind.television:
        if (s.isOn == true) {
          items.add(
            HouseCheckItem(
              d,
              HouseCheckProblem.mediaOn,
              when(d, Capability.power, const TurnOff()) ??
                  (s.raw == 'playing'
                      ? when(d, Capability.mediaPause, const MediaPlayPause())
                      : null),
            ),
          );
        }
      case DeviceKind.climate ||
          DeviceKind.thermostat ||
          DeviceKind.fan ||
          DeviceKind.airPurifier ||
          DeviceKind.humidifier ||
          DeviceKind.dehumidifier:
        // Heating overnight is normal; only leaving the house asks.
        if (mode == HouseCheckMode.leaving &&
            s.isOn == true &&
            s.hvacMode != 'off') {
          items.add(
            HouseCheckItem(
              d,
              HouseCheckProblem.climateOn,
              when(d, Capability.power, const TurnOff()),
            ),
          );
        }
      case _ when d.kind.isLight:
        if (s.isOn == true) {
          items.add(
            HouseCheckItem(
              d,
              HouseCheckProblem.lightOn,
              when(d, Capability.power, const TurnOff()),
            ),
          );
        }
      case _:
        break;
    }
  }
  items.sort((a, b) {
    final byProblem = a.problem.index.compareTo(b.problem.index);
    if (byProblem != 0) return -byProblem; // security first, lights last
    return a.device.name.toLowerCase().compareTo(b.device.name.toLowerCase());
  });
  return items;
}

/// The check over the devices this user may see (child mode hides some).
final houseCheckProvider =
    Provider.family<List<HouseCheckItem>, HouseCheckMode>((ref, mode) {
      final ids = ref.watch(visibleDeviceIdsProvider);
      final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
      return houseCheck([for (final id in ids) ?devices[id]], mode);
    });
