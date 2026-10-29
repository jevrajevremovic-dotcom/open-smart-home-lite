import 'package:flutter/foundation.dart';

/// Entries of the Home Assistant area, device and entity registries, as
/// returned by the WebSocket commands `config/area_registry/list`,
/// `config/device_registry/list` and `config/entity_registry/list` (the
/// commands the official frontend uses). Only fields the app needs are
/// parsed; malformed entries are skipped.

@immutable
class HaArea {
  const HaArea({
    required this.id,
    required this.name,
    this.icon,
    this.picture,
    this.floorId,
  });

  static HaArea? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['area_id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return HaArea(
      id: id,
      name: name,
      icon: _str(json['icon']),
      picture: _str(json['picture']),
      floorId: _str(json['floor_id']),
    );
  }

  final String id;
  final String name;
  final String? icon;
  final String? picture;
  final String? floorId;
}

/// Entry of `config/floor_registry/list` (HA 2024.4+).
@immutable
class HaFloor {
  const HaFloor({required this.id, required this.name, this.level});

  static HaFloor? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['floor_id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return HaFloor(
      id: id,
      name: name,
      level: json['level'] is int ? json['level']! as int : null,
    );
  }

  final String id;
  final String name;

  /// Storey number (0 = ground floor); `null` when not set.
  final int? level;
}

@immutable
class HaDeviceEntry {
  const HaDeviceEntry({
    required this.id,
    this.name,
    this.manufacturer,
    this.model,
    this.areaId,
    this.identifiers = const [],
    this.connections = const [],
    this.viaDeviceId,
  });

  static HaDeviceEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    return HaDeviceEntry(
      id: id,
      name: _str(json['name_by_user']) ?? _str(json['name']),
      manufacturer: _str(json['manufacturer']),
      model: _str(json['model']),
      areaId: _str(json['area_id']),
      identifiers: _pairs(json['identifiers']),
      connections: _pairs(json['connections']),
      viaDeviceId: _str(json['via_device_id']),
    );
  }

  final String id;
  final String? name;
  final String? manufacturer;
  final String? model;
  final String? areaId;

  /// `(integration domain, id)` pairs, e.g. `('mqtt', 'zigbee2mqtt_0x…')`.
  final List<(String, String)> identifiers;

  /// `(type, value)` pairs, e.g. `('mac', 'aa:bb:…')`, `('zigbee', '0x…')`.
  final List<(String, String)> connections;
  final String? viaDeviceId;
}

@immutable
class HaEntityEntry {
  const HaEntityEntry({
    required this.entityId,
    this.deviceId,
    this.areaId,
    this.platform,
    this.entityCategory,
    this.hidden = false,
    this.disabled = false,
  });

  static HaEntityEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final entityId = json['entity_id'];
    if (entityId is! String) return null;
    return HaEntityEntry(
      entityId: entityId,
      deviceId: _str(json['device_id']),
      areaId: _str(json['area_id']),
      platform: _str(json['platform']),
      entityCategory: _str(json['entity_category']),
      hidden: json['hidden_by'] != null,
      disabled: json['disabled_by'] != null,
    );
  }

  final String entityId;
  final String? deviceId;

  /// Overrides the device's area when set.
  final String? areaId;

  /// Integration providing the entity (`zha`, `mqtt`, `zwave_js`, …).
  final String? platform;

  /// `config` or `diagnostic` for auxiliary entities.
  final String? entityCategory;
  final bool hidden;
  final bool disabled;
}

/// Snapshot of the three registries. Empty when they could not be loaded
/// (e.g. older servers or restricted users): the app then works without
/// rooms and protocol information instead of failing.
@immutable
class HaRegistries {
  const HaRegistries({
    this.areas = const {},
    this.devices = const {},
    this.entities = const {},
    this.floors = const {},
  });

  static const HaRegistries empty = HaRegistries();

  factory HaRegistries.parse({
    required Object? areas,
    required Object? devices,
    required Object? entities,
    Object? floors,
  }) {
    Map<String, T> index<T>(
      Object? list,
      T? Function(Object?) parse,
      String Function(T) key,
    ) {
      if (list is! List) return const {};
      return {
        for (final item in list.map(parse).whereType<T>()) key(item): item,
      };
    }

    return HaRegistries(
      areas: index(areas, HaArea.tryParse, (a) => a.id),
      devices: index(devices, HaDeviceEntry.tryParse, (d) => d.id),
      entities: index(entities, HaEntityEntry.tryParse, (e) => e.entityId),
      floors: index(floors, HaFloor.tryParse, (f) => f.id),
    );
  }

  final Map<String, HaArea> areas;
  final Map<String, HaDeviceEntry> devices;
  final Map<String, HaEntityEntry> entities;
  final Map<String, HaFloor> floors;

  bool get isEmpty => areas.isEmpty && devices.isEmpty && entities.isEmpty;
}

String? _str(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<(String, String)> _pairs(Object? value) {
  if (value is! List) return const [];
  return [
    for (final pair in value)
      if (pair is List &&
          pair.length >= 2 &&
          pair[0] is String &&
          pair[1] is String)
        (pair[0] as String, pair[1] as String),
  ];
}
