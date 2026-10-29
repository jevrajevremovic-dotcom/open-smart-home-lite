import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../data/home_state_repository.dart';
import '../domain/device_command.dart';
import '../domain/home_backend.dart';
import 'device_providers.dart';
import '../domain/capability.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';

/// The single entry point for controlling devices.
///
/// Guards, in order: device available → capability declared → critical
/// commands confirmed. Only then is the command handed to the backend. The UI
/// is not updated optimistically; the backend's next snapshot does it.
class DeviceCommandService {
  DeviceCommandService(this._sink, {this._isOnline});

  final DeviceCommandSink _sink;

  /// Whether the shown data is live. Commands are refused while showing
  /// cached/stale data: the user could not see the real current state, nor
  /// the result of the command.
  final bool Function()? _isOnline;
  static final _log = AppLogger('DeviceCommand');

  Future<void> execute(
    SmartHomeDevice device,
    DeviceCommand command, {
    bool confirmed = false,
  }) async {
    if (!(_isOnline?.call() ?? true)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'data not live; command refused',
      );
    }
    if (!device.available) {
      throw AppFailure(
        FailureKind.unavailableEntity,
        debugMessage: '${device.id} unavailable',
      );
    }
    if (!device.supports(command.requiredCapability)) {
      throw AppFailure(
        FailureKind.unsupportedFeature,
        debugMessage: '${device.id} lacks ${command.requiredCapability.name}',
      );
    }
    if (command.isCritical(device) && !confirmed) {
      throw AppFailure(
        FailureKind.confirmationRequired,
        debugMessage:
            '${command.runtimeType} on ${device.id} needs confirmation',
      );
    }
    await _sink.send(device, command);
  }

  /// All [lights] on or off, in one request where the backend can.
  Future<void> setLights(
    Iterable<SmartHomeDevice> lights, {
    required bool on,
  }) async {
    if (!(_isOnline?.call() ?? true)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'data not live; command refused',
      );
    }
    final targets = [
      for (final d in lights)
        if (d.available && d.kind.isLight) d,
    ];
    if (targets.isEmpty) return;
    _log.info('→ lights ${on ? 'on' : 'off'} (${targets.length})');
    await _sink.sendToAll(targets, on ? const TurnOn() : const TurnOff());
  }

  /// Opens or closes all [covers] (blinds, curtains), in one request where
  /// the backend can. Garage doors are never included:
  /// opening one needs its own confirmation.
  Future<void> setCovers(
    Iterable<SmartHomeDevice> covers, {
    required bool open,
  }) async {
    if (!(_isOnline?.call() ?? true)) {
      throw const AppFailure(
        FailureKind.network,
        debugMessage: 'data not live; command refused',
      );
    }
    final targets = [
      for (final d in covers)
        if (d.available &&
            isGroupCover(d) &&
            d.supports(open ? Capability.open : Capability.close))
          d,
    ];
    if (targets.isEmpty) return;
    _log.info('→ covers ${open ? 'open' : 'close'} (${targets.length})');
    await _sink.sendToAll(
      targets,
      open ? const OpenCover() : const CloseCover(),
    );
  }
}

/// Blinds and curtains, the covers that may be moved together.
bool isGroupCover(SmartHomeDevice d) =>
    d.kind == DeviceKind.blind || d.kind == DeviceKind.curtain;

final deviceCommandServiceProvider = Provider<DeviceCommandService?>((ref) {
  final backend = ref.watch(homeBackendProvider);
  return backend == null
      ? null
      : DeviceCommandService(
          backend,
          isOnline: () => ref.read(syncStatusProvider) == SyncStatus.live,
        );
});
