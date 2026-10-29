import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../integrations/home_assistant/models/ha_calendar.dart';
import '../../authentication/application/session_controller.dart';

final _log = AppLogger('Calendar');

/// Calendar entities from Home Assistant (Google, CalDAV, local, …).
final calendarsProvider = FutureProvider<List<HaCalendar>>((ref) async {
  final api = ref.watch(homeAssistantApiProvider);
  if (api == null) return const [];
  final timer = Timer(const Duration(minutes: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final list = await api.fetchCalendars();
  return list..sort((a, b) => a.name.compareTo(b.name));
});

/// Fixed colour per calendar (by position), used for the event bars.
const calendarColors = [
  Color(0xFF3D7BFF),
  Color(0xFFFF7A45),
  Color(0xFF2DBE6C),
  Color(0xFFB065E8),
  Color(0xFFFFC233),
  Color(0xFF1FB5C9),
  Color(0xFFE5487D),
];

final calendarColorProvider = Provider.family<Color, String>((ref, id) {
  final list = ref.watch(calendarsProvider).value ?? const [];
  final i = list.indexWhere((c) => c.entityId == id);
  return calendarColors[(i < 0 ? 0 : i) % calendarColors.length];
});

/// Events from all calendars for the month containing [month], plus the
/// days around it that a month grid and an agenda show. Refreshed every
/// 5 minutes while visible. A calendar that fails is skipped, the others
/// are still shown; if all fail, the error is reported.
final calendarMonthEventsProvider = FutureProvider.autoDispose
    .family<List<HaCalendarEvent>, DateTime>((ref, month) async {
      final api = ref.watch(homeAssistantApiProvider);
      final calendars = await ref.watch(calendarsProvider.future);
      if (api == null || calendars.isEmpty) return const [];
      final timer = Timer(const Duration(minutes: 5), ref.invalidateSelf);
      ref.onDispose(timer.cancel);

      final start = DateTime(month.year, month.month, 1 - 7);
      final end = DateTime(month.year, month.month + 1, 1 + 21);
      Object? lastError;
      final results = await Future.wait([
        for (final c in calendars)
          api.fetchCalendarEvents(c.entityId, start, end).catchError((
            Object e,
          ) {
            lastError = e;
            _log.info(
              'Calendar ${c.entityId} failed: '
              '${e is AppFailure ? e.kind.name : e.runtimeType}',
            );
            return <HaCalendarEvent>[];
          }),
      ]);
      if (lastError != null && results.every((r) => r.isEmpty)) {
        throw lastError!;
      }
      return [for (final r in results) ...r]..sort(compareEvents);
    });

/// All-day events first, then by start time, then by title.
int compareEvents(HaCalendarEvent a, HaCalendarEvent b) {
  final day = DateUtils.dateOnly(a.start)
      .compareTo(DateUtils.dateOnly(b.start));
  if (day != 0) return day;
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final t = a.start.compareTo(b.start);
  return t != 0 ? t : a.summary.compareTo(b.summary);
}
