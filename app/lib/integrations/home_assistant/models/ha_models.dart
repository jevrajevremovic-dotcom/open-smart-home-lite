import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';

/// Subset of `GET /api/config` the app relies on.
/// https://developers.home-assistant.io/docs/api/rest/
@immutable
class HaConfig {
  const HaConfig({
    required this.locationName,
    required this.version,
    required this.timeZone,
    required this.temperatureUnit,
    required this.components,
    this.latitude,
    this.longitude,
  });

  factory HaConfig.fromJson(Object? json) {
    final map = _asMap(json, 'config');
    final version = map['version'];
    if (version is! String || version.isEmpty) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'config.version missing — not a Home Assistant server?',
      );
    }
    final unitSystem = map['unit_system'];
    return HaConfig(
      locationName: _string(map['location_name']) ?? 'Home',
      version: version,
      timeZone: _string(map['time_zone']),
      temperatureUnit: unitSystem is Map
          ? _string(unitSystem['temperature'])
          : null,
      components: switch (map['components']) {
        final List<Object?> list => list.whereType<String>().toSet(),
        _ => const <String>{},
      },
      latitude: map['latitude'] is num
          ? (map['latitude']! as num).toDouble()
          : null,
      longitude: map['longitude'] is num
          ? (map['longitude']! as num).toDouble()
          : null,
    );
  }

  final String locationName;
  final String version;
  final String? timeZone;
  final String? temperatureUnit;
  final Set<String> components;

  /// Home location set in Home Assistant (used only for the opt-in MET
  /// Norway forecast when there is no weather entity).
  final double? latitude;
  final double? longitude;
}

/// One entry of `GET /api/states` or `new_state` of a `state_changed` event.
///
/// Kept close to Home Assistant's wire format; translation into the
/// app's protocol-independent device model happens in a mapper (phase 5).
@immutable
class HaEntityState {
  const HaEntityState({
    required this.entityId,
    required this.state,
    required this.attributes,
    this.lastChanged,
    this.lastUpdated,
  });

  /// Throws [AppFailure] of kind [FailureKind.parsing] on invalid input.
  factory HaEntityState.fromJson(Object? json) {
    final map = _asMap(json, 'state');
    final entityId = map['entity_id'];
    if (entityId is! String || !_entityIdPattern.hasMatch(entityId)) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'invalid entity_id',
      );
    }
    final attributes = map['attributes'];
    return HaEntityState(
      entityId: entityId,
      state: _string(map['state']) ?? 'unknown',
      attributes: attributes is Map<String, Object?>
          ? Map.unmodifiable(attributes)
          : const {},
      lastChanged: _date(map['last_changed']),
      lastUpdated: _date(map['last_updated']),
    );
  }

  static final RegExp _entityIdPattern = RegExp(r'^[a-z0-9_]+\.[a-z0-9_]+$');

  final String entityId;
  final String state;
  final Map<String, Object?> attributes;
  final DateTime? lastChanged;
  final DateTime? lastUpdated;

  /// Wire format, used by the offline cache.
  Map<String, Object?> toJson() => {
    'entity_id': entityId,
    'state': state,
    'attributes': attributes,
    'last_changed': lastChanged?.toUtc().toIso8601String(),
    'last_updated': lastUpdated?.toUtc().toIso8601String(),
  };

  String get domain => entityId.substring(0, entityId.indexOf('.'));
  String get friendlyName => _string(attributes['friendly_name']) ?? entityId;
  bool get isUnavailable => state == 'unavailable';
}

/// `state_changed` event payload. `newState == null` means the entity was
/// removed; `oldState == null` means it was just added.
@immutable
class HaStateChangedEvent {
  const HaStateChangedEvent({
    required this.entityId,
    required this.oldState,
    required this.newState,
  });

  factory HaStateChangedEvent.fromEventData(Object? data) {
    final map = _asMap(data, 'event.data');
    final entityId = map['entity_id'];
    if (entityId is! String) {
      throw const AppFailure(
        FailureKind.parsing,
        debugMessage: 'event without entity_id',
      );
    }
    return HaStateChangedEvent(
      entityId: entityId,
      oldState: map['old_state'] == null
          ? null
          : HaEntityState.fromJson(map['old_state']),
      newState: map['new_state'] == null
          ? null
          : HaEntityState.fromJson(map['new_state']),
    );
  }

  final String entityId;
  final HaEntityState? oldState;
  final HaEntityState? newState;
}

/// Parses a list of states, skipping (not failing on) malformed entries so
/// one broken integration cannot blank the whole UI.
List<HaEntityState> parseStateList(
  Object? json, {
  void Function(Object error)? onSkipped,
}) {
  if (json is! List) {
    throw const AppFailure(
      FailureKind.parsing,
      debugMessage: 'states is not a list',
    );
  }
  final result = <HaEntityState>[];
  for (final item in json) {
    try {
      result.add(HaEntityState.fromJson(item));
    } on AppFailure catch (e) {
      onSkipped?.call(e);
    }
  }
  return result;
}

Map<String, Object?> _asMap(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw AppFailure(FailureKind.parsing, debugMessage: '$what is not an object');
}

String? _string(Object? value) => value is String ? value : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
