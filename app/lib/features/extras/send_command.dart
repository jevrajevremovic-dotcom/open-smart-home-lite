import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/logging/app_logger.dart';
import '../devices/application/device_command_service.dart';
import '../devices/application/device_providers.dart';
import '../devices/data/local/local_backend.dart';
import '../devices/domain/device_command.dart';

/// Sends one command to the device [deviceId] as it is now; a device that
/// is gone or does not answer is logged, not thrown.
typedef SendCommand = Future<void> Function(
  String deviceId,
  DeviceCommand command,
);

final _log = AppLogger('Extras');

/// A [SendCommand] for the home's backend, taken once (the screen that
/// starts a party or a story may be gone when it ends).
SendCommand commandSender(Ref ref) => _sender(ref.read(homeBackendProvider));

/// The same, from a widget.
SendCommand commandSenderOf(WidgetRef ref) =>
    _sender(ref.read(homeBackendProvider));

SendCommand _sender(LocalBackend? backend) {
  return (deviceId, command) async {
    if (backend == null) return;
    final device = backend.current.devices[deviceId];
    if (device == null) return;
    try {
      // Chosen by the household for this: no second confirmation.
      await DeviceCommandService(backend)
          .execute(device, command, confirmed: true);
    } on AppFailure catch (e) {
      _log.warning('$deviceId: ${command.runtimeType}', e);
    }
  };
}
