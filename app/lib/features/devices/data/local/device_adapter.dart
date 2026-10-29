import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';

/// One kind of device the phone talks to directly (Shelly, WLED, a
/// Bluetooth sensor family, the demo home): finds its devices, keeps their
/// state current and delivers commands to them.
///
/// Device ids are `<adapter id>:<id within the adapter>`, so [LocalBackend]
/// knows where each command goes.
abstract interface class DeviceAdapter {
  /// Short, stable, without `:` (`shelly`, `wled`, `demo`).
  String get id;

  /// Every change of the adapter's devices, as the full list.
  Stream<List<SmartHomeDevice>> get devices;

  /// The devices now.
  List<SmartHomeDevice> get current;

  Future<void> start();

  /// Already checked by `DeviceCommandService`; throws `AppFailure` when
  /// the device cannot be reached.
  Future<void> send(SmartHomeDevice device, DeviceCommand command);

  Future<void> dispose();
}
