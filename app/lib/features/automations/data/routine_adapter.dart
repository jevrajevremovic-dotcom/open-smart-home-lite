import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../devices/data/local/device_adapter.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../application/routines_controller.dart';

/// Runs scenes and automations (the automation engine).
abstract interface class RoutineRunner {
  Future<void> runScene(String sceneId);

  /// Runs the automation's actions now (its conditions are not asked).
  Future<void> runAutomation(String automationId);

  Future<void> setEnabled(String automationId, bool enabled);
}

/// The household's scenes and automations as devices (`routine:scene_…`,
/// `routine:auto_…`), so everything that shows scenes — the home's scene
/// buttons, the kiosk, quick tiles, shortcuts — shows these.
class RoutineAdapter extends DeviceAdapter {
  RoutineAdapter(Routines routines) : _routines = routines;

  Routines _routines;
  RoutineRunner? runner;
  final _controller = StreamController<List<SmartHomeDevice>>.broadcast();
  late List<SmartHomeDevice> _current = _build();

  static String sceneDevice(String id) => 'routine:scene_$id';
  static String automationDevice(String id) => 'routine:auto_$id';

  @override
  String get id => 'routine';

  @override
  Stream<List<SmartHomeDevice>> get devices => _controller.stream;

  @override
  List<SmartHomeDevice> get current => _current;

  void setRoutines(Routines routines) {
    _routines = routines;
    _current = _build();
    if (!_controller.isClosed) _controller.add(_current);
  }

  List<SmartHomeDevice> _build() => [
    for (final s in _routines.scenes)
      SmartHomeDevice(
        id: sceneDevice(s.id),
        sourceId: s.id,
        name: s.name,
        kind: DeviceKind.scene,
        protocol: DeviceProtocol.virtual,
        available: true,
        capabilities: const {Capability.trigger},
        state: const DeviceState(raw: 'scene'),
      ),
    for (final a in _routines.automations)
      SmartHomeDevice(
        id: automationDevice(a.id),
        sourceId: a.id,
        name: a.name,
        kind: DeviceKind.automation,
        protocol: DeviceProtocol.virtual,
        available: true,
        capabilities: const {Capability.power, Capability.trigger},
        state: DeviceState(
          raw: a.enabled ? 'on' : 'off',
          isOn: a.enabled,
          lastTriggered: a.lastTriggered,
        ),
      ),
  ];

  @override
  Future<void> start() async {}

  @override
  Future<void> send(SmartHomeDevice device, DeviceCommand command) async {
    final runner = this.runner;
    if (runner == null) {
      throw const AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: 'automations not running',
      );
    }
    final part = device.id.split(':').last;
    if (part.startsWith('scene_')) {
      return runner.runScene(part.substring(6));
    }
    final id = part.substring(5);
    switch (command) {
      case Activate():
        return runner.runAutomation(id);
      case TurnOn():
        return runner.setEnabled(id, true);
      case TurnOff():
        return runner.setEnabled(id, false);
      case Toggle():
        return runner.setEnabled(id, device.state.isOn != true);
      default:
        throw AppFailure(
          FailureKind.unsupportedFeature,
          debugMessage: '${command.runtimeType} for an automation',
        );
    }
  }

  @override
  Future<void> dispose() => _controller.close();
}
