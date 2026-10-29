import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/device_command.dart';
import '../../domain/home_backend.dart';
import '../../domain/home_snapshot.dart';
import '../../domain/smart_home_device.dart';
import 'device_adapter.dart';

/// The home without a server: the phone talks to each device itself,
/// through one [DeviceAdapter] per kind of device.
///
/// The snapshot is the adapters' devices merged; it is always live, since
/// there is no connection to lose (a device that cannot be reached is
/// reported unavailable by its adapter).
class LocalBackend implements HomeBackend {
  LocalBackend(
    this._adapters, {
    Map<String, Room> rooms = const {},
    String? homeName,
  }) : _snapshot = HomeSnapshot(rooms: rooms, locationName: homeName);

  final List<DeviceAdapter> _adapters;
  final StreamController<HomeSnapshot> _controller =
      StreamController<HomeSnapshot>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  HomeSnapshot _snapshot;
  bool _started = false;
  static final _log = AppLogger('LocalBackend');

  @override
  HomeSnapshot get current => _snapshot;

  @override
  Stream<HomeSnapshot> get snapshots => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
    for (final adapter in _adapters) {
      _subscriptions.add(adapter.devices.listen((_) => _merge()));
      unawaited(
        adapter.start().catchError(
          (Object e) => _log.warning('${adapter.id} did not start', e),
        ),
      );
    }
    _merge();
  }

  void _merge() {
    final devices = <String, SmartHomeDevice>{
      for (final adapter in _adapters)
        for (final d in adapter.current) d.id: d,
    };
    _emit(
      _snapshot.copyWith(
        devices: Map.unmodifiable(devices),
        status: SyncStatus.live,
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) =>
      _adapterFor(device).send(device, command);

  @override
  Future<void> sendToAll(
    List<SmartHomeDevice> devices,
    DeviceCommand command,
  ) async {
    // Each device separately; one that fails does not stop the others.
    AppFailure? first;
    for (final device in devices) {
      try {
        await send(device, command);
      } on AppFailure catch (e) {
        first ??= e;
      }
    }
    if (first != null) throw first;
  }

  DeviceAdapter _adapterFor(SmartHomeDevice device) {
    final prefix = device.id.split(':').first;
    for (final adapter in _adapters) {
      if (adapter.id == prefix) return adapter;
    }
    throw AppFailure(
      FailureKind.unavailableEntity,
      debugMessage: 'no adapter for ${device.id}',
    );
  }

  /// Nothing to save yet: the devices' state lives in the devices.
  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    for (final adapter in _adapters) {
      await adapter.dispose();
    }
    await _controller.close();
  }

  void _emit(HomeSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}
