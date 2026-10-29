import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';
import 'local_home.dart';

/// One kind of device the phone talks to directly (Shelly, WLED, a
/// Bluetooth sensor family, the demo home): finds its devices, keeps their
/// state current and delivers commands to them.
///
/// Device ids are `<adapter id>:<id within the adapter>`, so [LocalBackend]
/// knows where each command goes.
abstract class DeviceAdapter {
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

  /// The household's devices of this adapter (added, removed, moved to
  /// another address).
  void configure(List<ConfiguredDevice> devices) {}

  /// Asks every device for its state now.
  Future<void> refresh() async {}

  /// In the background the adapter stops asking its devices.
  void setActive(bool active) {}
}
