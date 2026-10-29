import 'package:flutter/foundation.dart';

import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';

/// A [DeviceCommand] as JSON, for the commands scenes and automations use;
/// `null` for others.
Map<String, Object?>? commandToJson(DeviceCommand c) => switch (c) {
  TurnOn() => {'do': 'on'},
  TurnOff() => {'do': 'off'},
  Toggle() => {'do': 'toggle'},
  SetBrightness(:final percent) => {'do': 'brightness', 'value': percent},
  SetColorTemperature(:final kelvin) => {'do': 'kelvin', 'value': kelvin},
  SetRgbColor(:final color) => {
    'do': 'rgb',
    'value': [color.red, color.green, color.blue],
  },
  OpenCover() => {'do': 'open'},
  CloseCover() => {'do': 'close'},
  SetCoverPosition(:final percent) => {'do': 'position', 'value': percent},
  SetTargetTemperature(:final temperature) => {
    'do': 'temperature',
    'value': temperature,
  },
  SetHvacMode(:final mode) => {'do': 'hvac', 'value': mode},
  LockDevice() => {'do': 'lock'},
  Activate() => {'do': 'activate'},
  _ => null,
};

DeviceCommand? commandFromJson(Object? json) {
  if (json is! Map) return null;
  final v = json['value'];
  int? i() => v is num ? v.round() : null;
  return switch (json['do']) {
    'on' => const TurnOn(),
    'off' => const TurnOff(),
    'toggle' => const Toggle(),
    'brightness' when i() != null => SetBrightness(i()!.clamp(0, 100)),
    'kelvin' when i() != null => SetColorTemperature(i()!),
    'rgb' when v is List && v.length == 3 && v.every((c) => c is num) =>
      SetRgbColor(
        RgbColor(
          (v[0] as num).round(),
          (v[1] as num).round(),
          (v[2] as num).round(),
        ),
      ),
    'open' => const OpenCover(),
    'close' => const CloseCover(),
    'position' when i() != null => SetCoverPosition(i()!.clamp(0, 100)),
    'temperature' when v is num => SetTargetTemperature(v.toDouble()),
    'hvac' when v is String => SetHvacMode(v),
    'lock' => const LockDevice(),
    'activate' => const Activate(),
    _ => null,
  };
}

/// One command for one device.
@immutable
class DeviceAction {
  const DeviceAction(this.deviceId, this.command);

  final String deviceId;
  final DeviceCommand command;

  Map<String, Object?>? toJson() => switch (commandToJson(command)) {
    final c? => {'device': deviceId, ...c},
    null => null,
  };

  static DeviceAction? fromJson(Object? json) {
    if (json is! Map || json['device'] is! String) return null;
    final c = commandFromJson(json);
    return c == null ? null : DeviceAction(json['device'] as String, c);
  }
}

/// Devices whose current state can be kept in a scene.
bool canStoreInScene(SmartHomeDevice d) =>
    d.available &&
    !d.isAuxiliary &&
    (d.kind.isLight ||
        d.kind == DeviceKind.switchDevice ||
        d.kind == DeviceKind.outlet ||
        d.kind == DeviceKind.blind ||
        d.kind == DeviceKind.curtain ||
        d.kind == DeviceKind.climate ||
        d.kind == DeviceKind.thermostat);

/// The commands that bring [d] back to how it is now.
List<DeviceAction> actionsForState(SmartHomeDevice d) {
  final s = d.state;
  if (d.kind.isLight ||
      d.kind == DeviceKind.switchDevice ||
      d.kind == DeviceKind.outlet) {
    if (s.isOn != true) return [DeviceAction(d.id, const TurnOff())];
    return [
      if (s.brightnessPercent case final b?
          when d.supports(Capability.brightness))
        DeviceAction(d.id, SetBrightness(b))
      else
        DeviceAction(d.id, const TurnOn()),
      if (s.rgb case final c? when d.supports(Capability.rgb))
        DeviceAction(d.id, SetRgbColor(c))
      else if (s.colorTemperatureKelvin case final k?
          when d.supports(Capability.colorTemperature))
        DeviceAction(d.id, SetColorTemperature(k)),
    ];
  }
  if (d.kind == DeviceKind.blind || d.kind == DeviceKind.curtain) {
    return [
      if (s.position case final p? when d.supports(Capability.position))
        DeviceAction(d.id, SetCoverPosition(p))
      else if (s.coverState == CoverState.closed)
        DeviceAction(d.id, const CloseCover())
      else
        DeviceAction(d.id, const OpenCover()),
    ];
  }
  return [
    if (s.hvacMode case final m? when d.supports(Capability.hvacMode))
      DeviceAction(d.id, SetHvacMode(m)),
    if (s.targetTemperature case final t?
        when d.supports(Capability.targetTemperature))
      DeviceAction(d.id, SetTargetTemperature(t)),
  ];
}

@immutable
class LocalScene {
  const LocalScene({
    required this.id,
    required this.name,
    this.actions = const [],
  });

  final String id;
  final String name;
  final List<DeviceAction> actions;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'actions': [for (final a in actions) ?a.toJson()],
  };

  static LocalScene? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['name'] is! String) {
      return null;
    }
    return LocalScene(
      id: json['id'] as String,
      name: json['name'] as String,
      actions: [
        for (final a in (json['actions'] as List?) ?? const [])
          ?DeviceAction.fromJson(a),
      ],
    );
  }
}

/// Time of day.
@immutable
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  @override
  int compareTo(ClockTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ClockTime? parse(Object? text) {
    if (text is! String) return null;
    final [h, m, ...] = '$text:'.split(':');
    final hour = int.tryParse(h), minute = int.tryParse(m);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return ClockTime(hour, minute);
  }
}

/// A device's state a trigger or condition looks for.
enum DeviceStateTarget {
  on,
  off,
  open,
  closed,
  active,
  inactive,
  locked,
  unlocked;

  bool matches(SmartHomeDevice d) {
    final s = d.state;
    return switch (this) {
      on => s.isOn == true,
      off => s.isOn == false,
      open =>
        s.coverState == CoverState.open ||
            s.coverState == CoverState.opening ||
            (d.kind == DeviceKind.contactSensor && s.isActive == true),
      closed =>
        s.coverState == CoverState.closed ||
            (d.kind == DeviceKind.contactSensor && s.isActive == false),
      active => s.isActive == true,
      inactive => s.isActive == false,
      locked => s.lockState == DoorLockState.locked,
      unlocked => s.lockState == DoorLockState.unlocked,
    };
  }

  /// The states [d] can be in.
  static List<DeviceStateTarget> of(SmartHomeDevice d) => switch (d.kind) {
    DeviceKind.contactSensor ||
    DeviceKind.blind ||
    DeviceKind.curtain ||
    DeviceKind.garageDoor => const [open, closed],
    DeviceKind.lock => const [locked, unlocked],
    _ when d.kind.isSensor || d.kind == DeviceKind.binarySensor => const [
      active,
      inactive,
    ],
    _ => const [on, off],
  };
}

sealed class AutomationTrigger {
  const AutomationTrigger();

  Map<String, Object?> toJson();

  static AutomationTrigger? fromJson(Object? json) {
    if (json is! Map) return null;
    final offset = json['offset'];
    final threshold = json['threshold'];
    return switch (json['type']) {
      'time' => switch (ClockTime.parse(json['at'])) {
        final at? => TimeTrigger(at),
        null => null,
      },
      'sun' => SunTrigger(
        sunset: json['sunset'] == true,
        offsetMinutes: offset is num ? offset.round() : 0,
      ),
      'device' when json['device'] is String => switch (DeviceStateTarget.values
          .where((t) => t.name == json['to'])
          .firstOrNull) {
        final to? => DeviceTrigger(json['device'] as String, to),
        null => null,
      },
      'value' when json['device'] is String && threshold is num => ValueTrigger(
        json['device'] as String,
        above: json['above'] != false,
        threshold: threshold.toDouble(),
      ),
      _ => null,
    };
  }
}

/// Every day at [at] (the days, if any, are a condition).
class TimeTrigger extends AutomationTrigger {
  const TimeTrigger(this.at);

  final ClockTime at;

  @override
  Map<String, Object?> toJson() => {'type': 'time', 'at': '$at'};
}

/// At sunrise or sunset, [offsetMinutes] before (negative) or after.
class SunTrigger extends AutomationTrigger {
  const SunTrigger({required this.sunset, this.offsetMinutes = 0});

  final bool sunset;
  final int offsetMinutes;

  @override
  Map<String, Object?> toJson() => {
    'type': 'sun',
    'sunset': sunset,
    'offset': offsetMinutes,
  };
}

/// When a device comes into [to] (a door opens, motion, a light on).
class DeviceTrigger extends AutomationTrigger {
  const DeviceTrigger(this.deviceId, this.to);

  final String deviceId;
  final DeviceStateTarget to;

  @override
  Map<String, Object?> toJson() => {
    'type': 'device',
    'device': deviceId,
    'to': to.name,
  };
}

/// When a reading crosses [threshold] (rises above, or falls below).
class ValueTrigger extends AutomationTrigger {
  const ValueTrigger(
    this.deviceId, {
    required this.above,
    required this.threshold,
  });

  final String deviceId;
  final bool above;
  final double threshold;

  @override
  Map<String, Object?> toJson() => {
    'type': 'value',
    'device': deviceId,
    'above': above,
    'threshold': threshold,
  };
}

sealed class AutomationCondition {
  const AutomationCondition();

  Map<String, Object?> toJson();

  static AutomationCondition? fromJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['type']) {
      'days' => WeekdayCondition({
        for (final d in (json['days'] as List?) ?? const [])
          if (d is int && d >= 1 && d <= 7) d,
      }),
      'between' => TimeWindowCondition(
        after: ClockTime.parse(json['after']),
        before: ClockTime.parse(json['before']),
      ),
      'device' when json['device'] is String => switch (DeviceStateTarget.values
          .where((t) => t.name == json['is'])
          .firstOrNull) {
        final s? => StateCondition(json['device'] as String, s),
        null => null,
      },
      'dark' => DarkCondition(dark: json['dark'] != false),
      _ => null,
    };
  }
}

/// Only on these days (`DateTime.monday` … `DateTime.sunday`).
class WeekdayCondition extends AutomationCondition {
  const WeekdayCondition(this.weekdays);

  final Set<int> weekdays;

  @override
  Map<String, Object?> toJson() => {
    'type': 'days',
    'days': weekdays.toList()..sort(),
  };
}

/// Only between [after] and [before] (over midnight if [before] is
/// earlier).
class TimeWindowCondition extends AutomationCondition {
  const TimeWindowCondition({this.after, this.before});

  final ClockTime? after;
  final ClockTime? before;

  bool includes(ClockTime t) {
    final a = after, b = before;
    if (a == null && b == null) return true;
    if (a == null) return t.compareTo(b!) < 0;
    if (b == null) return t.compareTo(a) >= 0;
    return a.compareTo(b) <= 0
        ? t.compareTo(a) >= 0 && t.compareTo(b) < 0
        : t.compareTo(a) >= 0 || t.compareTo(b) < 0;
  }

  @override
  Map<String, Object?> toJson() => {
    'type': 'between',
    'after': ?after?.toString(),
    'before': ?before?.toString(),
  };
}

/// Only while a device is in a state.
class StateCondition extends AutomationCondition {
  const StateCondition(this.deviceId, this.state);

  final String deviceId;
  final DeviceStateTarget state;

  @override
  Map<String, Object?> toJson() => {
    'type': 'device',
    'device': deviceId,
    'is': state.name,
  };
}

/// Only when it is dark (between sunset and sunrise), or only by day.
class DarkCondition extends AutomationCondition {
  const DarkCondition({required this.dark});

  final bool dark;

  @override
  Map<String, Object?> toJson() => {'type': 'dark', 'dark': dark};
}

@immutable
class LocalAutomation {
  const LocalAutomation({
    required this.id,
    required this.name,
    this.enabled = true,
    this.triggers = const [],
    this.conditions = const [],
    this.actions = const [],
    this.lastTriggered,
  });

  final String id;
  final String name;
  final bool enabled;
  final List<AutomationTrigger> triggers;
  final List<AutomationCondition> conditions;

  /// Device commands, or a scene (`scene:<id>` with [Activate]).
  final List<DeviceAction> actions;
  final DateTime? lastTriggered;

  bool get isComplete => triggers.isNotEmpty && actions.isNotEmpty;

  LocalAutomation copyWith({
    String? name,
    bool? enabled,
    List<AutomationTrigger>? triggers,
    List<AutomationCondition>? conditions,
    List<DeviceAction>? actions,
    DateTime? lastTriggered,
  }) => LocalAutomation(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    triggers: triggers ?? this.triggers,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
    lastTriggered: lastTriggered ?? this.lastTriggered,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'triggers': [for (final t in triggers) t.toJson()],
    'conditions': [for (final c in conditions) c.toJson()],
    'actions': [for (final a in actions) ?a.toJson()],
    'last': ?lastTriggered?.toUtc().toIso8601String(),
  };

  static LocalAutomation? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['name'] is! String) {
      return null;
    }
    return LocalAutomation(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] != false,
      triggers: [
        for (final t in (json['triggers'] as List?) ?? const [])
          ?AutomationTrigger.fromJson(t),
      ],
      conditions: [
        for (final c in (json['conditions'] as List?) ?? const [])
          ?AutomationCondition.fromJson(c),
      ],
      actions: [
        for (final a in (json['actions'] as List?) ?? const [])
          ?DeviceAction.fromJson(a),
      ],
      lastTriggered: DateTime.tryParse('${json['last']}')?.toLocal(),
    );
  }
}
