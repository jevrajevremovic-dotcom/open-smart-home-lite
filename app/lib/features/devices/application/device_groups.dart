import 'package:flutter/foundation.dart';

import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';

/// The entities of one physical device (Home Assistant device registry),
/// shown as one thing: an air fryer with its start/pause buttons, modes,
/// timers and sensors is one card, not twenty.
@immutable
class DeviceBundle {
  DeviceBundle(this.members)
    : assert(members.isNotEmpty),
      name = _groupName(members);

  final List<SmartHomeDevice> members;

  /// What the entities' names have in common ("Mi Smart Air Fryer (3.5L)"),
  /// or the main entity's name.
  final String name;

  /// `group:<device id>`, or the entity id for a single entity.
  String get key => members.length == 1
      ? members.first.id
      : 'group:${members.first.deviceId}';

  bool get isGroup => members.length > 1;

  /// The entity that best stands for the device (its main switch, light,
  /// climate…), first among equals.
  SmartHomeDevice get primary {
    var best = members.first;
    for (final d in members.skip(1)) {
      if (primaryRank(d) < primaryRank(best)) best = d;
    }
    return best;
  }

  bool get available => members.any((d) => d.available);

  /// A member's name without the device's name ("Air Fryer Pause").
  String shortName(SmartHomeDevice d) {
    if (!isGroup || !d.name.startsWith(name)) return d.name;
    final rest = d.name
        .substring(name.length)
        .replaceFirst(RegExp(r'^[\s\-–—:,|/*]+'), '');
    if (rest.isEmpty) return d.name;
    return rest[0].toUpperCase() + rest.substring(1);
  }

  /// Lower is more "the device itself".
  static int primaryRank(SmartHomeDevice d) => switch (d.kind) {
    _ when d.kind.isLight => 0,
    DeviceKind.climate ||
    DeviceKind.thermostat ||
    DeviceKind.mediaPlayer ||
    DeviceKind.speaker ||
    DeviceKind.television ||
    DeviceKind.fan ||
    DeviceKind.airPurifier ||
    DeviceKind.vacuum ||
    DeviceKind.humidifier ||
    DeviceKind.dehumidifier ||
    DeviceKind.blind ||
    DeviceKind.curtain ||
    DeviceKind.garageDoor ||
    DeviceKind.lock ||
    DeviceKind.alarm ||
    DeviceKind.camera => 0,
    DeviceKind.switchDevice || DeviceKind.outlet => 1,
    DeviceKind.select || DeviceKind.number => 3,
    DeviceKind.button => 4,
    _ when d.kind.isSensor => 5,
    _ => 6,
  };

  static String _groupName(List<SmartHomeDevice> members) {
    if (members.length == 1) return members.first.name;
    var prefix = members.first.name.split(' ');
    for (final d in members.skip(1)) {
      final words = d.name.split(' ');
      var i = 0;
      while (i < prefix.length && i < words.length && prefix[i] == words[i]) {
        i++;
      }
      prefix = prefix.sublist(0, i);
    }
    final common = prefix.join(' ').trim();
    // Too little in common to name the device: its main entity's name.
    return common.length >= 3
        ? common
        : members
              .reduce((a, b) => primaryRank(a) <= primaryRank(b) ? a : b)
              .name;
  }
}

/// [devices] grouped by physical device, in the order they first appear.
/// Entities without a device stay on their own.
List<DeviceBundle> groupDevices(Iterable<SmartHomeDevice> devices) {
  final byDevice = <String, List<SmartHomeDevice>>{};
  final order = <Object>[];
  for (final d in devices) {
    final id = d.deviceId;
    if (id == null) {
      order.add(d);
    } else {
      final list = byDevice[id];
      if (list == null) {
        byDevice[id] = [d];
        order.add(id);
      } else {
        list.add(d);
      }
    }
  }
  return [
    for (final o in order)
      o is SmartHomeDevice ? DeviceBundle([o]) : DeviceBundle(byDevice[o]!),
  ];
}
