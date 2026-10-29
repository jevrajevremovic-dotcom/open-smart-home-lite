import 'package:flutter/foundation.dart';

/// One state of an entity at a point in time (`GET /api/history/period`).
@immutable
class HaHistoryPoint {
  const HaHistoryPoint(this.at, this.state);

  final DateTime at;
  final String state;

  /// Response: a list with one list per entity; with `minimal_response`
  /// only the first item carries the entity id.
  static List<HaHistoryPoint> parse(Object? json) {
    if (json is! List || json.isEmpty || json.first is! List) return const [];
    return [
      for (final p in json.first as List)
        if (p is Map &&
            p['state'] is String &&
            p['last_changed'] is String &&
            DateTime.tryParse(p['last_changed']! as String) != null)
          HaHistoryPoint(
            DateTime.parse(p['last_changed']! as String).toLocal(),
            p['state']! as String,
          ),
    ];
  }
}

/// Entry of `GET /api/logbook`.
@immutable
class HaLogbookEntry {
  const HaLogbookEntry({
    required this.when,
    this.entityId,
    this.name,
    this.state,
    this.message,
    this.byUser = false,
  });

  final DateTime when;
  final String? entityId;

  /// Friendly name HA had for the entity at the time.
  final String? name;
  final String? state;
  final String? message;

  /// Caused by a person (app / dashboard) rather than an automation.
  final bool byUser;

  static List<HaLogbookEntry> parse(Object? json) => [
    if (json is List)
      for (final e in json)
        if (e is Map &&
            e['when'] is String &&
            DateTime.tryParse(e['when']! as String) != null)
          HaLogbookEntry(
            when: DateTime.parse(e['when']! as String).toLocal(),
            entityId: e['entity_id'] is String
                ? e['entity_id']! as String
                : null,
            name: e['name'] is String ? e['name']! as String : null,
            state: e['state'] is String ? e['state']! as String : null,
            message: e['message'] is String ? e['message']! as String : null,
            byUser: e['context_user_id'] is String,
          ),
  ]..sort((a, b) => b.when.compareTo(a.when));
}
