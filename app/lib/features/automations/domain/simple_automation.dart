import 'package:flutter/foundation.dart';

import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';

/// A time of day without a date, as HA writes it (`HH:MM:SS`).
@immutable
class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  static String _two(int v) => v.toString().padLeft(2, '0');

  String toHa() => '${_two(hour)}:${_two(minute)}:00';

  static ClockTime? parse(Object? value) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('$value');
    if (m == null) return null;
    final h = int.parse(m[1]!);
    final min = int.parse(m[2]!);
    return h < 24 && min < 60 ? ClockTime(h, min) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// When an automation runs.
sealed class AutomationTrigger {
  const AutomationTrigger();

  Map<String, Object?> toConfig();
}

/// At a time of day.
class TimeTrigger extends AutomationTrigger {
  const TimeTrigger(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  Map<String, Object?> toConfig() => {
    'trigger': 'time',
    'at': ClockTime(hour, minute).toHa(),
  };
}

/// When a device changes to [toState] (HA state, e.g. `on`, `home`).
class DeviceTrigger extends AutomationTrigger {
  const DeviceTrigger(this.entityId, this.toState);

  final String entityId;
  final String toState;

  @override
  Map<String, Object?> toConfig() => {
    'trigger': 'state',
    'entity_id': entityId,
    'to': toState,
  };
}

/// When a sensor's value rises above or falls below [threshold].
class NumericTrigger extends AutomationTrigger {
  const NumericTrigger(
    this.entityId, {
    required this.above,
    required this.threshold,
  });

  final String entityId;

  /// `true` = fires when the value goes above, `false` = below.
  final bool above;
  final num threshold;

  @override
  Map<String, Object?> toConfig() => {
    'trigger': 'numeric_state',
    'entity_id': entityId,
    above ? 'above' : 'below': threshold,
  };
}

/// At sunrise or sunset, shifted by [offsetMinutes].
class SunTrigger extends AutomationTrigger {
  const SunTrigger({required this.sunset, this.offsetMinutes = 0});

  final bool sunset;
  final int offsetMinutes;

  @override
  Map<String, Object?> toConfig() => {
    'trigger': 'sun',
    'event': sunset ? 'sunset' : 'sunrise',
    'offset': _offset(offsetMinutes),
  };

  static String _offset(int minutes) {
    final sign = minutes < 0 ? '-' : '';
    final m = minutes.abs();
    return '$sign${ClockTime._two(m ~/ 60)}:${ClockTime._two(m % 60)}:00';
  }
}

/// Checked after a trigger fires; all conditions must hold ("and").
sealed class AutomationCondition {
  const AutomationCondition();

  Map<String, Object?> toConfig();
}

/// Only on these weekdays (1 = Monday).
class WeekdayCondition extends AutomationCondition {
  const WeekdayCondition(this.weekdays);

  final Set<int> weekdays;

  static const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Map<String, Object?> toConfig() => {
    'condition': 'time',
    'weekday': [for (final d in (weekdays.toList()..sort())) days[d - 1]],
  };
}

/// Only between [after] and [before]; HA handles windows over midnight.
class TimeWindowCondition extends AutomationCondition {
  const TimeWindowCondition({this.after, this.before})
    : assert(after != null || before != null);

  final ClockTime? after;
  final ClockTime? before;

  @override
  Map<String, Object?> toConfig() => {
    'condition': 'time',
    if (after != null) 'after': after!.toHa(),
    if (before != null) 'before': before!.toHa(),
  };
}

/// Only while a device is in [state].
class StateCondition extends AutomationCondition {
  const StateCondition(this.entityId, this.state);

  final String entityId;
  final String state;

  @override
  Map<String, Object?> toConfig() => {
    'condition': 'state',
    'entity_id': entityId,
    'state': state,
  };
}

/// Only while it is dark (sun below the horizon) or light.
class SunCondition extends AutomationCondition {
  const SunCondition({required this.dark});

  final bool dark;

  @override
  Map<String, Object?> toConfig() => {
    'condition': 'state',
    'entity_id': 'sun.sun',
    'state': dark ? 'below_horizon' : 'above_horizon',
  };
}

/// What an automation does: call [service] on [entityId].
@immutable
class AutomationAction {
  const AutomationAction(this.entityId, this.service);

  final String entityId;

  /// Service name in the entity's domain, e.g. `turn_on`, `close_cover`.
  final String service;

  String get domain => entityId.split('.').first;
}

/// An automation the app can create; saved as a normal Home Assistant
/// automation (visible and editable in HA afterwards). Any trigger
/// starts it, and it runs only if every condition holds.
@immutable
class SimpleAutomation {
  const SimpleAutomation({
    required this.alias,
    required this.triggers,
    this.conditions = const [],
    required this.actions,
  });

  final String alias;
  final List<AutomationTrigger> triggers;
  final List<AutomationCondition> conditions;
  final List<AutomationAction> actions;

  /// HA automation config (2024.10+ format: `triggers` / `actions`).
  Map<String, Object?> toConfig(String id) => {
    'id': id,
    'alias': alias,
    'description': 'Open Smart Home',
    'mode': 'single',
    'triggers': [for (final t in triggers) t.toConfig()],
    'conditions': [for (final c in conditions) c.toConfig()],
    'actions': [
      for (final a in actions)
        {
          'action': '${a.domain}.${a.service}',
          'target': {'entity_id': a.entityId},
        },
    ],
  };

  /// Reads a config back if it only uses what this editor can show:
  /// time/state/numeric/sun triggers, weekday/time/state conditions and
  /// actions that call a service on entity targets. `null` = edit in HA.
  static SimpleAutomation? tryParse(Map<String, Object?> config) {
    List<Object?> list(String plural, String singular) =>
        switch (config[plural] ?? config[singular]) {
          final List<Object?> l => l,
          final Map<Object?, Object?> m => [m],
          _ => const [],
        };

    final triggers = <AutomationTrigger>[];
    for (final t in list('triggers', 'trigger')) {
      final parsed = t is Map ? _parseTrigger(t) : null;
      if (parsed == null) return null;
      triggers.add(parsed);
    }
    if (triggers.isEmpty) return null;

    final conditions = <AutomationCondition>[];
    for (final c in list('conditions', 'condition')) {
      final parsed = c is Map ? _parseCondition(c) : null;
      if (parsed == null) return null;
      conditions.addAll(parsed);
    }

    final actions = <AutomationAction>[];
    for (final a in list('actions', 'action')) {
      if (a is! Map) return null;
      final service = (a['action'] ?? a['service']);
      final target = a['target'];
      final id = target is Map ? target['entity_id'] : a['entity_id'];
      final ids = id is List ? id : [id];
      if (service is! String || !service.contains('.')) return null;
      if (a.keys.any((k) => !_actionKeys.contains(k))) return null;
      for (final e in ids) {
        if (e is! String) return null;
        actions.add(AutomationAction(e, service.split('.').last));
      }
    }
    if (actions.isEmpty) return null;
    return SimpleAutomation(
      alias: config['alias'] is String ? config['alias']! as String : '',
      triggers: triggers,
      conditions: conditions,
      actions: actions,
    );
  }

  static const _actionKeys = {'action', 'service', 'target', 'entity_id'};

  static String? _single(Object? id) =>
      switch (id is List && id.length == 1 ? id.first : id) {
        final String s => s,
        _ => null,
      };

  static AutomationTrigger? _parseTrigger(Map<Object?, Object?> t) {
    final kind = t['trigger'] ?? t['platform'];
    bool only(Set<String> keys) => t.keys.every(
      (k) => keys.contains(k) || k == 'trigger' || k == 'platform' || k == 'id',
    );
    switch (kind) {
      case 'time':
        final at = ClockTime.parse(t['at']);
        if (at == null || !only({'at'})) return null;
        return TimeTrigger(at.hour, at.minute);
      case 'state':
        final id = _single(t['entity_id']);
        final to = t['to'];
        if (id == null || to is! String || !only({'entity_id', 'to'})) {
          return null;
        }
        return DeviceTrigger(id, to);
      case 'numeric_state':
        final id = _single(t['entity_id']);
        final above = t['above'];
        final below = t['below'];
        if (id == null || !only({'entity_id', 'above', 'below'})) return null;
        if (above is num && below == null) {
          return NumericTrigger(id, above: true, threshold: above);
        }
        if (below is num && above == null) {
          return NumericTrigger(id, above: false, threshold: below);
        }
        return null;
      case 'sun':
        if (!only({'event', 'offset'})) return null;
        final m = RegExp(r'^(-?)(\d{1,2}):(\d{2})')
            .firstMatch('${t['offset'] ?? '00:00:00'}');
        final minutes = m == null
            ? 0
            : (int.parse(m[2]!) * 60 + int.parse(m[3]!)) *
                  (m[1] == '-' ? -1 : 1);
        return SunTrigger(
          sunset: t['event'] == 'sunset',
          offsetMinutes: minutes,
        );
      default:
        return null;
    }
  }

  /// One HA time condition may hold weekdays and a window; split it.
  static List<AutomationCondition>? _parseCondition(Map<Object?, Object?> c) {
    switch (c['condition']) {
      case 'time':
        if (c.keys.any(
          (k) => !const {'condition', 'weekday', 'after', 'before'}.contains(k),
        )) {
          return null;
        }
        final out = <AutomationCondition>[];
        final wd = c['weekday'];
        if (wd != null) {
          final days = {
            for (final d in wd is List ? wd : [wd])
              if (WeekdayCondition.days.indexOf('$d') case final i when i >= 0)
                i + 1,
          };
          if (days.isEmpty) return null;
          out.add(WeekdayCondition(days));
        }
        final after = c['after'];
        final before = c['before'];
        final a = after == null ? null : ClockTime.parse(after);
        final b = before == null ? null : ClockTime.parse(before);
        if ((after != null && a == null) || (before != null && b == null)) {
          return null; // e.g. `after: input_datetime.x`
        }
        if (a != null || b != null) {
          out.add(TimeWindowCondition(after: a, before: b));
        }
        return out.isEmpty ? null : out;
      case 'state':
        final id = _single(c['entity_id']);
        final state = c['state'];
        if (id == null ||
            state is! String ||
            c.keys.any(
              (k) => !const {'condition', 'entity_id', 'state'}.contains(k),
            )) {
          return null;
        }
        if (id == 'sun.sun') {
          return switch (state) {
            'below_horizon' => [const SunCondition(dark: true)],
            'above_horizon' => [const SunCondition(dark: false)],
            _ => null,
          };
        }
        return [StateCondition(id, state)];
      default:
        return null;
    }
  }
}

/// States a device can be watched for (`to:`), as HA states.
List<String> triggerStatesFor(SmartHomeDevice d) => switch (d.kind) {
  DeviceKind.person => const ['home', 'not_home'],
  DeviceKind.lock => const ['unlocked', 'locked'],
  DeviceKind.blind ||
  DeviceKind.curtain ||
  DeviceKind.garageDoor => const ['open', 'closed'],
  _ when d.kind.isSensor && d.state.numericValue != null => const [],
  DeviceKind.camera ||
  DeviceKind.weather ||
  DeviceKind.select ||
  DeviceKind.number ||
  DeviceKind.todoList ||
  DeviceKind.unknown => const [],
  _ when d.kind.isRoutine => const [],
  _ => const ['on', 'off'],
};

/// Sensors whose value can trigger an automation (`numeric_state`).
bool hasNumericTrigger(SmartHomeDevice d) =>
    d.kind.isSensor && d.state.numericValue != null;

/// Services an automation may call on a device. Unlocking and disarming
/// are left out on purpose: they belong in Home Assistant's own editor.
List<String> actionServicesFor(SmartHomeDevice d) => switch (d.kind) {
  DeviceKind.scene || DeviceKind.script => const ['turn_on'],
  DeviceKind.blind || DeviceKind.curtain => const ['open_cover', 'close_cover'],
  DeviceKind.lock => const ['lock'],
  DeviceKind.vacuum => const ['start', 'return_to_base'],
  DeviceKind.mediaPlayer ||
  DeviceKind.speaker ||
  DeviceKind.television => const ['media_play', 'media_pause', 'turn_off'],
  _ when d.kind.isLight => const ['turn_on', 'turn_off'],
  DeviceKind.switchDevice ||
  DeviceKind.outlet ||
  DeviceKind.fan ||
  DeviceKind.climate ||
  DeviceKind.thermostat ||
  DeviceKind.humidifier ||
  DeviceKind.dehumidifier ||
  DeviceKind.siren => const ['turn_on', 'turn_off'],
  _ => const [],
};
