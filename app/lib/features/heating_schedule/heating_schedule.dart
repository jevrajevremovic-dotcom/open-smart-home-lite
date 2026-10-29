import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../devices/application/device_providers.dart';
import '../ha_notify/ha_push.dart';

/// One automation per thermostat.
String heatingScheduleId(String climateId) =>
    'osh_schedule_${haSlug(climateId)}';

/// From [minute] (since midnight) on, keep [temperature].
@immutable
class SchedulePoint {
  const SchedulePoint(this.minute, this.temperature);

  final int minute;
  final double temperature;

  int get hour => minute ~/ 60;

  /// `06:30`
  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SchedulePoint &&
      other.minute == minute &&
      other.temperature == temperature;

  @override
  int get hashCode => Object.hash(minute, temperature);
}

/// A week of target temperatures: one day plan for workdays and one for
/// the weekend. Saved as a Home Assistant automation (time triggers,
/// weekday conditions, `climate.set_temperature`), so it runs without
/// the app.
@immutable
class HeatingSchedule {
  const HeatingSchedule({
    required this.climateId,
    required this.workdays,
    required this.weekend,
  });

  /// Radnim danima 21° od 6 do 8 i od 16 do 22, noću 18°; vikendom 21°
  /// od 8 do 23.
  factory HeatingSchedule.suggested(String climateId) => HeatingSchedule(
    climateId: climateId,
    workdays: const [
      SchedulePoint(6 * 60, 21),
      SchedulePoint(8 * 60, 18),
      SchedulePoint(16 * 60, 21),
      SchedulePoint(22 * 60, 18),
    ],
    weekend: const [SchedulePoint(8 * 60, 21), SchedulePoint(23 * 60, 18)],
  );

  /// Back from the saved automation (its `variables`), or null.
  static HeatingSchedule? fromAutomation(Map<String, Object?> config) {
    final v = config['variables'];
    if (v is! Map) return null;
    final climate = v['osh_climate'];
    if (climate is! String) return null;
    List<SchedulePoint> points(Object? raw) => [
      if (raw is List)
        for (final p in raw)
          if (p is List && p.length == 2 && p[0] is int && p[1] is num)
            SchedulePoint(p[0] as int, (p[1] as num).toDouble()),
    ]..sort((a, b) => a.minute.compareTo(b.minute));
    return HeatingSchedule(
      climateId: climate,
      workdays: points(v['osh_workdays']),
      weekend: points(v['osh_weekend']),
    );
  }

  static const workdayNames = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const weekendNames = ['sat', 'sun'];

  final String climateId;
  final List<SchedulePoint> workdays;
  final List<SchedulePoint> weekend;

  String get id => heatingScheduleId(climateId);

  bool get isEmpty => workdays.isEmpty && weekend.isEmpty;

  HeatingSchedule copyWith({
    List<SchedulePoint>? workdays,
    List<SchedulePoint>? weekend,
  }) => HeatingSchedule(
    climateId: climateId,
    workdays: workdays ?? this.workdays,
    weekend: weekend ?? this.weekend,
  );

  /// The point in force at [now] and the next one, for the summary.
  (SchedulePoint?, SchedulePoint?) around(DateTime now) {
    List<SchedulePoint> on(DateTime day) =>
        day.weekday >= DateTime.saturday ? weekend : workdays;
    final minute = now.hour * 60 + now.minute;
    final today = on(now);
    SchedulePoint? current;
    SchedulePoint? next;
    for (final p in today) {
      if (p.minute <= minute) {
        current = p;
      } else {
        next ??= p;
      }
    }
    if (current == null) {
      // Still the last one of an earlier day.
      for (var back = 1; back <= 7 && current == null; back++) {
        final day = on(now.subtract(Duration(days: back)));
        if (day.isNotEmpty) current = day.last;
      }
    }
    if (next == null) {
      for (var ahead = 1; ahead <= 7 && next == null; ahead++) {
        final day = on(now.add(Duration(days: ahead)));
        if (day.isNotEmpty) next = day.first;
      }
    }
    return (current, next);
  }

  Map<String, Object?> automation(AppLocalizations l10n, String name) {
    final times = {
      for (final p in [...workdays, ...weekend]) p.hhmm,
    }.toList()..sort();
    Map<String, Object?> option(SchedulePoint p, List<String> days) => {
      'conditions': [
        {'condition': 'trigger', 'id': p.hhmm},
        {'condition': 'time', 'weekday': days},
      ],
      'sequence': [
        {
          'action': 'climate.set_temperature',
          'target': {'entity_id': climateId},
          'data': {'temperature': p.temperature},
        },
      ],
    };
    return {
      'alias': l10n.heatingScheduleAlias(name),
      'description': 'Open Smart Home',
      'mode': 'single',
      'variables': {
        'osh_climate': climateId,
        'osh_workdays': [
          for (final p in workdays) [p.minute, p.temperature],
        ],
        'osh_weekend': [
          for (final p in weekend) [p.minute, p.temperature],
        ],
      },
      'triggers': [
        for (final t in times) {'trigger': 'time', 'at': '$t:00', 'id': t},
      ],
      'conditions': <Object>[],
      'actions': [
        {
          'choose': [
            for (final p in workdays) option(p, workdayNames),
            for (final p in weekend) option(p, weekendNames),
          ],
        },
      ],
    };
  }
}

/// Whether the thermostat's schedule exists (its entity carries the id).
final heatingScheduleSetProvider = Provider.family<bool, String>((
  ref,
  climateId,
) {
  final id = heatingScheduleId(climateId);
  return ref.watch(
    homeSnapshotProvider.select(
      (s) => s.devices.values.any((d) => d.metadata.configId == id),
    ),
  );
});
