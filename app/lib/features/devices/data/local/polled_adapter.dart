import 'dart:async';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import 'device_adapter.dart';
import 'local_home.dart';

/// An adapter for devices on the local network that are asked for their
/// state every [pollEvery] (and right after each command). A device that
/// does not answer keeps its last state, marked unavailable.
abstract class PolledAdapter extends DeviceAdapter {
  PolledAdapter({this.pollEvery = const Duration(seconds: 5)});

  final Duration pollEvery;
  late final AppLogger _log = AppLogger('Adapter:$id');

  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  final Map<String, ConfiguredDevice> _configs = {};

  /// Last answer of each physical device, by [ConfiguredDevice.key].
  final Map<String, List<SmartHomeDevice>> _read = {};
  final Set<String> _unreachable = {};
  List<SmartHomeDevice> _current = const [];
  Timer? _timer;
  bool _active = true;
  bool _started = false;
  bool _disposed = false;

  /// The channels of [device] as it answers now; throws `AppFailure`.
  Future<List<SmartHomeDevice>> read(ConfiguredDevice device);

  /// Delivers [command] for [channel] of [device]; throws `AppFailure`.
  Future<void> command(
    ConfiguredDevice device,
    SmartHomeDevice channel,
    DeviceCommand command,
  );

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => _current;

  @override
  void configure(List<ConfiguredDevice> devices) {
    final next = {for (final d in devices) d.key: d};
    final changed = next.entries
        .where((e) => _configs[e.key] != e.value)
        .map((e) => e.key)
        .toList();
    for (final key in _configs.keys.toList()) {
      if (!next.containsKey(key)) {
        _configs.remove(key);
        _read.remove(key);
        _unreachable.remove(key);
      }
    }
    _configs.addAll(next);
    _publish();
    if (_started) {
      for (final key in changed) {
        unawaited(_poll(key));
      }
    }
  }

  @override
  Future<void> start() async {
    _started = true;
    _schedule();
    await refresh();
  }

  @override
  Future<void> refresh() =>
      Future.wait([for (final key in _configs.keys.toList()) _poll(key)]);

  @override
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _schedule();
    if (active && _started) unawaited(refresh());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_active || _disposed) return;
    _timer = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
  }

  Future<void> _poll(String key) async {
    final config = _configs[key];
    if (config == null || _disposed) return;
    try {
      final channels = await read(config);
      if (_disposed || _configs[key] != config) return;
      _read[key] = channels;
      _unreachable.remove(key);
    } on Object catch (e) {
      // Not answering, or an answer that could not be read.
      if (_disposed) return;
      if (_unreachable.add(key)) _log.warning('${config.host} unreachable', e);
    }
    _publish();
  }

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final config = _configs[device.deviceId];
    if (config == null || _unreachable.contains(config.key)) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} not reachable',
      );
    }
    await this.command(config, device, command);
    await _poll(config.key);
  }

  void _publish() {
    final out = <SmartHomeDevice>[];
    for (final config in _configs.values) {
      final channels = _read[config.key];
      final reachable = !_unreachable.contains(config.key);
      if (channels == null) {
        out.add(_placeholder(config));
      } else {
        out.addAll(
          reachable ? channels : [for (final c in channels) _unavailable(c)],
        );
      }
    }
    _current = List.unmodifiable(out);
    if (!_controller.isClosed) _controller.add(_current);
  }

  /// Not heard from yet: an unavailable card with the device's name.
  SmartHomeDevice _placeholder(ConfiguredDevice config) => SmartHomeDevice(
    id: '${config.key}:device',
    sourceId: config.host,
    deviceId: config.key,
    name: config.label ?? config.model ?? config.host,
    kind: DeviceKind.switchDevice,
    protocol: DeviceProtocol.wifi,
    model: config.model,
    available: false,
    capabilities: const {},
    state: const DeviceState(raw: 'unknown'),
  );

  static SmartHomeDevice _unavailable(SmartHomeDevice d) => SmartHomeDevice(
    id: d.id,
    sourceId: d.sourceId,
    name: d.name,
    kind: d.kind,
    available: false,
    capabilities: d.capabilities,
    state: d.state,
    deviceId: d.deviceId,
    roomId: d.roomId,
    protocol: d.protocol,
    manufacturer: d.manufacturer,
    model: d.model,
    limits: d.limits,
    metadata: d.metadata,
    isAuxiliary: d.isAuxiliary,
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _controller.close();
  }
}
