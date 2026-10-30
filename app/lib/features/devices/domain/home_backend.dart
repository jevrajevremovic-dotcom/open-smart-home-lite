import 'device_command.dart';
import 'home_snapshot.dart';
import 'smart_home_device.dart';

/// Where commands go. Implementations only translate and deliver:
/// availability, capability and confirmation are checked before, by
/// `DeviceCommandService`.
abstract interface class DeviceCommandSink {
  Future<void> send(SmartHomeDevice device, DeviceCommand command);

  /// The same command to several devices, in one request where the backend
  /// can (all lights off, all blinds up).
  Future<void> sendToAll(List<SmartHomeDevice> devices, DeviceCommand command);
}

/// The home as one backend sees it: the Wi-Fi and
/// Bluetooth devices themselves. The rest of the app knows only this,
/// [HomeSnapshot] and [SmartHomeDevice].
abstract interface class HomeBackend implements DeviceCommandSink {
  HomeSnapshot get current;
  Stream<HomeSnapshot> get snapshots;

  void start();

  /// Saves pending changes now (the app goes to the background).
  Future<void> flush();

  Future<void> dispose();
}
