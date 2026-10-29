import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../automations/application/routines_controller.dart';
import '../automations/domain/routines.dart';
import '../devices/domain/device_command.dart';

/// The ids of a thermostat's schedule automations start with this.
String heatingScheduleId(String climateId) =>
    'heat_${climateId.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}_';

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
/// the weekend. Saved as the home's automations, one per change (time
/// trigger, weekday condition, target temperature), so they show and run
/// like the others.
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

  /// Back from the home's automations, or `null` without any.
  static HeatingSchedule? fromAutomations(
    String climateId,
    Iterable<LocalAutomation> automations,
  ) {
    final prefix = heatingScheduleId(climateId);
    final workdays = <SchedulePoint>[];
    final weekend = <SchedulePoint>[];
    for (final a in automations) {
      if (!a.id.startsWith(prefix)) continue;
      final time = a.triggers.whereType<TimeTrigger>().firstOrNull?.at;
      final temperature = a.actions
          .map((x) => x.command)
          .whereType<SetTargetTemperature>()
          .firstOrNull
          ?.temperature;
      if (time == null || temperature == null) continue;
      final point = SchedulePoint(time.minutes, temperature);
      (a.id.substring(prefix.length).startsWith('we') ? weekend : workdays).add(
        point,
      );
    }
    if (workdays.isEmpty && weekend.isEmpty) return null;
    int byTime(SchedulePoint a, SchedulePoint b) =>
        a.minute.compareTo(b.minute);
    return HeatingSchedule(
      climateId: climateId,
      workdays: workdays..sort(byTime),
      weekend: weekend..sort(byTime),
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

  /// One automation per change of temperature, named after [name].
  List<LocalAutomation> toAutomations(String name) => [
    for (final (days, points, tag) in [
      ({1, 2, 3, 4, 5}, workdays, 'wd'),
      ({6, 7}, weekend, 'we'),
    ])
      for (final p in points)
        LocalAutomation(
          id: '$id$tag${p.minute}',
          name: '$name · ${p.hhmm} ${p.temperature}°',
          triggers: [TimeTrigger(ClockTime(p.hour, p.minute % 60))],
          conditions: [WeekdayCondition(days)],
          actions: [
            DeviceAction(climateId, SetTargetTemperature(p.temperature)),
          ],
        ),
  ];
}

/// The saved schedule of a thermostat, from the home's automations.
final heatingScheduleProvider = Provider.family<HeatingSchedule?, String>(
  (ref, climateId) => HeatingSchedule.fromAutomations(
    climateId,
    ref.watch(routinesProvider).automations,
  ),
);

/// Whether the thermostat has a schedule.
final heatingScheduleSetProvider = Provider.family<bool, String>(
  (ref, climateId) => ref.watch(heatingScheduleProvider(climateId)) != null,
);
