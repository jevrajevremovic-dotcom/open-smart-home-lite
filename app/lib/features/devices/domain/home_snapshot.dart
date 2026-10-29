import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import 'smart_home_device.dart';

enum SyncStatus {
  /// Nothing loaded yet.
  initial,

  /// Loading a snapshot after (re)connecting.
  syncing,

  /// Snapshot loaded and live events are flowing.
  live,

  /// Showing the last known data; the connection is down.
  stale,
}

@immutable
class HomeSnapshot {
  const HomeSnapshot({
    this.devices = const {},
    this.rooms = const {},
    this.status = SyncStatus.initial,
    this.lastSyncedAt,
    this.failure,
    this.locationName,
  });

  static const HomeSnapshot empty = HomeSnapshot();

  /// By device id (= entity id).
  final Map<String, SmartHomeDevice> devices;
  final Map<String, Room> rooms;
  final SyncStatus status;

  /// Last time live data was confirmed (snapshot or event).
  final DateTime? lastSyncedAt;
  final AppFailure? failure;

  /// The home's name, as the backend knows it (cached too).
  final String? locationName;

  bool get hasData => devices.isNotEmpty;

  /// Data is confirmed current; commands may be sent.
  bool get isLive => status == SyncStatus.live;

  HomeSnapshot copyWith({
    Map<String, SmartHomeDevice>? devices,
    Map<String, Room>? rooms,
    SyncStatus? status,
    DateTime? lastSyncedAt,
    AppFailure? failure,
    String? locationName,
    bool clearFailure = false,
  }) => HomeSnapshot(
    devices: devices ?? this.devices,
    rooms: rooms ?? this.rooms,
    status: status ?? this.status,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failure: clearFailure ? null : (failure ?? this.failure),
    locationName: locationName ?? this.locationName,
  );
}
