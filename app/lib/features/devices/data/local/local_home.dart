import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../../../core/storage/credential_store.dart';
import '../../domain/smart_home_device.dart';

/// A physical device the household added: where it is on the network and
/// which adapter talks to it.
@immutable
class ConfiguredDevice {
  const ConfiguredDevice({
    required this.adapter,
    required this.id,
    required this.host,
    this.model,
    this.label,
    this.secured = false,
  });

  /// [DeviceAdapter.id] (`shelly`, `wled`).
  final String adapter;

  /// Stable id within the adapter (the MAC address, lower case, no colons).
  final String id;

  /// IP address or host name on the local network.
  final String host;
  final String? model;

  /// Name shown while the device has not answered yet.
  final String? label;

  /// The device asks for a password; it is in the phone's secure storage
  /// ([devicePasswordId]), never here.
  final bool secured;

  /// Id of the physical device, shared by its channels
  /// (`SmartHomeDevice.deviceId`).
  String get key => '$adapter:$id';

  ConfiguredDevice copyWith({
    String? host,
    String? model,
    String? label,
    bool? secured,
  }) => ConfiguredDevice(
    adapter: adapter,
    id: id,
    host: host ?? this.host,
    model: model ?? this.model,
    label: label ?? this.label,
    secured: secured ?? this.secured,
  );

  Map<String, Object?> toJson() => {
    'adapter': adapter,
    'id': id,
    'host': host,
    'model': ?model,
    'label': ?label,
    if (secured) 'secured': true,
  };

  static ConfiguredDevice? fromJson(Object? json) {
    if (json is! Map) return null;
    final adapter = json['adapter'];
    final id = json['id'];
    final host = json['host'];
    if (adapter is! String || id is! String || host is! String) return null;
    return ConfiguredDevice(
      adapter: adapter,
      id: id,
      host: host,
      model: json['model'] as String?,
      label: json['label'] as String?,
      secured: json['secured'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConfiguredDevice &&
      other.adapter == adapter &&
      other.id == id &&
      other.host == host &&
      other.model == model &&
      other.label == label &&
      other.secured == secured;

  @override
  int get hashCode => Object.hash(adapter, id, host, model, label, secured);
}

/// Where the password of the device [key] is kept (`CredentialStore`).
String devicePasswordId(String key) => 'device:$key';

/// The home on this phone: its rooms, the devices added to it, and the
/// household's names and rooms for them. Stored locally.
@immutable
class LocalHome {
  const LocalHome({
    this.rooms = const [],
    this.devices = const [],
    this.names = const {},
    this.roomOf = const {},
    this.demo = true,
  });

  final List<Room> rooms;
  final List<ConfiguredDevice> devices;

  /// The household's name for a device (by `SmartHomeDevice.id` or, for a
  /// whole physical device, by [ConfiguredDevice.key]).
  final Map<String, String> names;

  /// Room id by `SmartHomeDevice.id` or [ConfiguredDevice.key]; a channel
  /// without its own room is where its physical device is.
  final Map<String, String> roomOf;

  /// Whether the demo home is shown (until the first real device).
  final bool demo;

  List<ConfiguredDevice> devicesOf(String adapter) => [
    for (final d in devices)
      if (d.adapter == adapter) d,
  ];

  /// [device] with the household's name and room.
  SmartHomeDevice overlay(SmartHomeDevice device) {
    final name = names[device.id];
    // Its own room, else its physical device's, else (a bridge's light)
    // the bridge's.
    final added = device.id.split(':').take(2).join(':');
    final room =
        roomOf[device.id] ??
        (device.deviceId == null ? null : roomOf[device.deviceId]) ??
        roomOf[added];
    if (name == null && room == null) return device;
    return SmartHomeDevice(
      id: device.id,
      sourceId: device.sourceId,
      name: name ?? device.name,
      kind: device.kind,
      available: device.available,
      capabilities: device.capabilities,
      state: device.state,
      deviceId: device.deviceId,
      roomId: room ?? device.roomId,
      protocol: device.protocol,
      manufacturer: device.manufacturer,
      model: device.model,
      limits: device.limits,
      metadata: device.metadata,
      isAuxiliary: device.isAuxiliary,
    );
  }

  LocalHome copyWith({
    List<Room>? rooms,
    List<ConfiguredDevice>? devices,
    Map<String, String>? names,
    Map<String, String>? roomOf,
    bool? demo,
  }) => LocalHome(
    rooms: rooms ?? this.rooms,
    devices: devices ?? this.devices,
    names: names ?? this.names,
    roomOf: roomOf ?? this.roomOf,
    demo: demo ?? this.demo,
  );

  Map<String, Object?> toJson() => {
    'rooms': [
      for (final r in rooms) {'id': r.id, 'name': r.name, 'icon': ?r.icon},
    ],
    'devices': [for (final d in devices) d.toJson()],
    'names': names,
    'roomOf': roomOf,
    'demo': demo,
  };

  /// Tolerant: a broken entry is skipped, not the whole home.
  static LocalHome fromJson(Map<String, Object?>? json) {
    if (json == null) return const LocalHome();
    Map<String, String> strings(Object? m) => {
      if (m is Map)
        for (final e in m.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
    return LocalHome(
      rooms: [
        for (final r in (json['rooms'] as List?) ?? const [])
          if (r is Map && r['id'] is String && r['name'] is String)
            Room(
              id: r['id'] as String,
              name: r['name'] as String,
              icon: r['icon'] as String?,
            ),
      ],
      devices: [
        for (final d in (json['devices'] as List?) ?? const [])
          ?ConfiguredDevice.fromJson(d),
      ],
      names: strings(json['names']),
      roomOf: strings(json['roomOf']),
      demo: json['demo'] != false,
    );
  }
}

class LocalHomeController extends Notifier<LocalHome> {
  static const _key = 'localHome';

  @override
  LocalHome build() =>
      LocalHome.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  Future<void> _save(LocalHome home) async {
    state = home;
    await ref.read(appPreferencesProvider).writeJson(_key, home.toJson());
  }

  /// Adds [device] (or updates its address), in [roomId], with its
  /// [password] if it asks for one. The first real device ends the demo.
  Future<void> addDevice(
    ConfiguredDevice device, {
    String? roomId,
    String? password,
  }) async {
    if (password != null && password.isNotEmpty) {
      await ref
          .read(credentialStoreProvider)
          .writeCredential(devicePasswordId(device.key), password);
      device = device.copyWith(secured: true);
    }
    final rest = [
      for (final d in state.devices)
        if (d.key != device.key) d,
    ];
    await _save(
      state.copyWith(
        devices: [...rest, device],
        roomOf: {...state.roomOf, device.key: ?roomId},
        demo: false,
      ),
    );
  }

  /// A device's new password (`null`: it no longer has one).
  Future<void> setPassword(String key, String? password) async {
    final store = ref.read(credentialStoreProvider);
    final secured = password != null && password.isNotEmpty;
    if (secured) {
      await store.writeCredential(devicePasswordId(key), password);
    } else {
      await store.deleteCredential(devicePasswordId(key));
    }
    // A changed device is asked again, with the new password.
    await _save(
      state.copyWith(
        devices: [
          for (final d in state.devices)
            d.key == key ? d.copyWith(secured: secured) : d,
        ],
      ),
    );
  }

  /// Removes a physical device, with its names, rooms and password.
  Future<void> removeDevice(String key) async {
    bool ofDevice(String id) => id == key || id.startsWith('$key:');
    await ref
        .read(credentialStoreProvider)
        .deleteCredential(devicePasswordId(key));
    await _save(
      state.copyWith(
        devices: [
          for (final d in state.devices)
            if (d.key != key) d,
        ],
        names: {
          for (final e in state.names.entries)
            if (!ofDevice(e.key)) e.key: e.value,
        },
        roomOf: {
          for (final e in state.roomOf.entries)
            if (!ofDevice(e.key)) e.key: e.value,
        },
      ),
    );
  }

  /// A new address found for a device (DHCP gave it another one).
  Future<void> updateHost(String key, String host) => _save(
    state.copyWith(
      devices: [
        for (final d in state.devices)
          d.key == key ? d.copyWith(host: host) : d,
      ],
    ),
  );

  /// The household's [name] (empty: the device's own) and room for [id].
  Future<void> setNameAndRoom(String id, String? name, String? roomId) {
    final names = {...state.names}..remove(id);
    if (name != null && name.trim().isNotEmpty) names[id] = name.trim();
    final roomOf = {...state.roomOf}..remove(id);
    if (roomId != null) roomOf[id] = roomId;
    return _save(state.copyWith(names: names, roomOf: roomOf));
  }

  /// Creates a room; returns its id.
  Future<String> addRoom(String name) async {
    final id = 'room_${DateTime.now().microsecondsSinceEpoch}';
    await _save(
      state.copyWith(
        rooms: [
          ...state.rooms,
          Room(id: id, name: name.trim()),
        ],
      ),
    );
    return id;
  }

  /// Removes a room; its devices are then in no room.
  Future<void> removeRoom(String id) => _save(
    state.copyWith(
      rooms: [
        for (final r in state.rooms)
          if (r.id != id) r,
      ],
      roomOf: {
        for (final e in state.roomOf.entries)
          if (e.value != id) e.key: e.value,
      },
    ),
  );

  Future<void> setDemo(bool demo) => _save(state.copyWith(demo: demo));

  /// From a backup: all of it ([replace]), or only what is missing here
  /// (devices, rooms, names and rooms of devices not set here).
  Future<void> importHome(LocalHome other, {required bool replace}) {
    if (replace) return _save(other);
    final here = state;
    return _save(
      here.copyWith(
        rooms: [
          ...here.rooms,
          for (final r in other.rooms)
            if (!here.rooms.any((x) => x.id == r.id)) r,
        ],
        devices: [
          ...here.devices,
          for (final d in other.devices)
            if (!here.devices.any((x) => x.key == d.key)) d,
        ],
        names: {...other.names, ...here.names},
        roomOf: {...other.roomOf, ...here.roomOf},
        demo: here.demo && other.demo,
      ),
    );
  }
}

final localHomeProvider = NotifierProvider<LocalHomeController, LocalHome>(
  LocalHomeController.new,
);
