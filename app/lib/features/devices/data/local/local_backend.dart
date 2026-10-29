import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/device_command.dart';
import '../../domain/home_backend.dart';
import '../../domain/home_snapshot.dart';
import '../../domain/smart_home_device.dart';
import 'demo_adapter.dart';
import 'device_adapter.dart';
import 'local_home.dart';

/// The home without a server: the phone talks to each device itself,
/// through one [DeviceAdapter] per kind of device.
///
/// The snapshot is the adapters' devices merged, with the household's
/// names and rooms ([LocalHome]) on top. It is always live, since there is
/// no connection to lose (a device that cannot be reached is reported
/// unavailable by its adapter).
class LocalBackend implements HomeBackend {
  LocalBackend(
    this._adapters, {
    Map<String, Room> rooms = const {},
    LocalHome? home,
    String? homeName,
  }) : _extraRooms = rooms,
       _home = home ?? const LocalHome(),
       _snapshot = HomeSnapshot(locationName: homeName);

  final List<DeviceAdapter> _adapters;

  /// Rooms not in [LocalHome] (the demo's, tests').
  final Map<String, Room> _extraRooms;
  LocalHome _home;
  final StreamController<HomeSnapshot> _controller =
      StreamController<HomeSnapshot>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  HomeSnapshot _snapshot;
  bool _started = false;
  static final _log = AppLogger('LocalBackend');

  @override
  HomeSnapshot get current => _snapshot;

  /// The household's devices, names and rooms in use.
  LocalHome get home => _home;

  @override
  Stream<HomeSnapshot> get snapshots => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
    for (final adapter in _adapters) {
      adapter.configure(_home.devicesOf(adapter.id));
      _subscriptions.add(adapter.devices.listen((_) => _merge()));
      unawaited(
        adapter.start().catchError(
          (Object e) => _log.warning('${adapter.id} did not start', e),
        ),
      );
    }
    _merge();
  }

  /// The household changed its devices, names or rooms.
  void configure(LocalHome home) {
    _home = home;
    for (final adapter in _adapters) {
      adapter.configure(home.devicesOf(adapter.id));
    }
    _merge();
  }

  /// Asks every device for its state now (pull to refresh).
  Future<void> refresh() async {
    await Future.wait([for (final a in _adapters) a.refresh()]);
  }

  /// The app went to the background (`false`) or came back.
  void setActive(bool active) {
    for (final adapter in _adapters) {
      adapter.setActive(active);
    }
  }

  void _merge() {
    final devices = <String, SmartHomeDevice>{
      for (final adapter in _adapters)
        if (adapter is! DemoAdapter || _home.demo)
          for (final d in adapter.current) d.id: _home.overlay(d),
    };
    final rooms = <String, Room>{
      if (_home.demo || _adapters.every((a) => a is! DemoAdapter))
        ..._extraRooms,
      for (final r in _home.rooms) r.id: r,
    };
    _emit(
      _snapshot.copyWith(
        devices: Map.unmodifiable(devices),
        rooms: Map.unmodifiable(rooms),
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
    await Future.wait([
      for (final device in devices)
        send(device, command).catchError((Object e) {
          if (e is! AppFailure) throw e;
          first ??= e;
        }),
    ]);
    if (first != null) throw first!;
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

  /// Nothing to save: the devices' state lives in the devices.
  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    // All at once: the adapters stop their timers right away.
    await Future.wait([
      for (final s in _subscriptions) s.cancel(),
      for (final adapter in _adapters) adapter.dispose(),
    ]);
    _subscriptions.clear();
    await _controller.close();
  }

  void _emit(HomeSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}
