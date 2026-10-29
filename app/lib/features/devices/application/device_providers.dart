import '../../restricted/application/restricted_mode.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/value_list.dart';
import '../../../integrations/home_assistant/ha_backend.dart';
import '../../authentication/application/session_controller.dart';
import '../data/cache/snapshot_cache.dart';
import '../data/home_state_repository.dart';
import '../domain/home_backend.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';

/// The active home's backend; lives as long as the session's connection.
final homeBackendProvider = Provider<HomeBackend?>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  final api = ref.watch(homeAssistantApiProvider);
  if (manager == null || api == null) return null;
  final backend = HaBackend(
    HomeStateRepository(
      manager,
      cache: ref.watch(snapshotCacheProvider),
      serverId: ref.watch(activeProfileProvider)?.id,
    ),
    HaCommandSink(api),
  )..start();
  ref.onDispose(() => unawaited(backend.dispose()));
  return backend;
});

class HomeSnapshotController extends Notifier<HomeSnapshot> {
  @override
  HomeSnapshot build() {
    final backend = ref.watch(homeBackendProvider);
    if (backend == null) return HomeSnapshot.empty;
    final subscription = backend.snapshots.listen((s) => state = s);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return backend.current;
  }
}

final homeSnapshotProvider =
    NotifierProvider<HomeSnapshotController, HomeSnapshot>(
      HomeSnapshotController.new,
    );

/// One device. Widgets watching it rebuild only when *this* device changes,
/// because the repository keeps unchanged devices identical.
final deviceProvider = Provider.family<SmartHomeDevice?, String>(
  (ref, id) => ref.watch(homeSnapshotProvider.select((s) => s.devices[id])),
);

final syncStatusProvider = Provider<SyncStatus>(
  (ref) => ref.watch(homeSnapshotProvider.select((s) => s.status)),
);

/// Devices meant for normal lists: no auxiliary entities, no routines.
final visibleDeviceIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final restricted = ref.watch(restrictedModeProvider);
  final visible =
      devices.values
          .where(
            (d) =>
                !d.isAuxiliary &&
                !d.kind.isRoutine &&
                d.kind != DeviceKind.unknown &&
                d.kind != DeviceKind.weather &&
                d.kind != DeviceKind.person &&
                d.kind != DeviceKind.todoList &&
                !restricted.hides(d),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final d in visible) d.id]);
});

/// Rooms sorted by name.
final roomsProvider = Provider<ValueList<Room>>((ref) {
  final rooms =
      ref.watch(homeSnapshotProvider.select((s) => s.rooms)).values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList(rooms);
});

/// Visible device ids per room id; devices without a room use `null`.
final deviceIdsByRoomProvider = Provider<Map<String?, ValueList<String>>>((
  ref,
) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final result = <String?, List<String>>{};
  for (final id in ref.watch(visibleDeviceIdsProvider)) {
    result.putIfAbsent(devices[id]?.roomId, () => []).add(id);
  }
  return {for (final e in result.entries) e.key: ValueList(e.value)};
});
