import 'package:flutter/foundation.dart';

/// Entry of `GET /api/calendars`.
@immutable
class HaCalendar {
  const HaCalendar(this.entityId, this.name);

  final String entityId;
  final String name;

  static List<HaCalendar> parseList(Object? json) => [
    if (json is List)
      for (final c in json)
        if (c is Map && c['entity_id'] is String)
          HaCalendar(
            c['entity_id']! as String,
            c['name'] is String
                ? c['name']! as String
                : c['entity_id']! as String,
          ),
  ];
}

/// Event of `GET /api/calendars/<entity_id>`. `start`/`end` are either
/// `{"dateTime": "...+02:00"}` or, for all-day events, `{"date": "2026-10-13"}`
/// with an exclusive end date.
@immutable
class HaCalendarEvent {
  const HaCalendarEvent({
    required this.calendarId,
    required this.summary,
    required this.start,
    required this.end,
    required this.allDay,
    this.location,
    this.description,
  });

  final String calendarId;
  final String summary;

  /// Local time. For all-day events: midnight of the first day.
  final DateTime start;

  /// Local time, exclusive. For all-day events: midnight after the last day.
  final DateTime end;
  final bool allDay;
  final String? location;
  final String? description;

  /// Whether the event covers any part of the local [day].
  bool occursOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    return start.isBefore(to) && end.isAfter(from) ||
        // Zero-length events at the start of the day.
        (start == end && !start.isBefore(from) && start.isBefore(to));
  }

  static List<HaCalendarEvent> parseList(Object? json, String calendarId) {
    if (json is! List) return const [];
    final out = <HaCalendarEvent>[];
    for (final e in json) {
      if (e is! Map) continue;
      final start = _time(e['start']);
      final end = _time(e['end']);
      if (start == null) continue;
      out.add(
        HaCalendarEvent(
          calendarId: calendarId,
          summary: e['summary'] is String ? e['summary']! as String : '',
          start: start.$1,
          end: end?.$1 ?? start.$1,
          allDay: start.$2,
          location: _nonEmpty(e['location']),
          description: _nonEmpty(e['description']),
        ),
      );
    }
    return out;
  }

  /// `(local time, isDateOnly)`.
  static (DateTime, bool)? _time(Object? v) {
    if (v is String) v = {'dateTime': v};
    if (v is! Map) return null;
    final dt = v['dateTime'];
    if (dt is String) {
      final parsed = DateTime.tryParse(dt);
      if (parsed != null) return (parsed.toLocal(), false);
    }
    final d = v['date'];
    if (d is String) {
      final parsed = DateTime.tryParse(d);
      if (parsed != null) {
        return (DateTime(parsed.year, parsed.month, parsed.day), true);
      }
    }
    return null;
  }

  static String? _nonEmpty(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;
}
