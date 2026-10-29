import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/logging/app_logger.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import '../ha_notify/ha_push.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../kiosk/application/kiosk_people.dart';

final _log = AppLogger('UnlockLog');

/// Writes who unlocked, opened or disarmed [device] into Home Assistant's
/// logbook (`logbook.log`: `name`, `message`, `entity_id`), e.g. "Marko
/// unlocks Front door (wall panel)". Who: on the wall panel the member who
/// tapped their picture or typed their PIN, else the panel; on a phone,
/// its name in Home Assistant. Best effort: never blocks the action.
Future<void> logCriticalAction(
  WidgetRef ref,
  AppLocalizations l10n,
  SmartHomeDevice device,
  DeviceCommand command,
) async {
  // Everything is read now: the screen may be gone after the await.
  final api = ref.read(homeAssistantApiProvider);
  if (api == null) return;
  final kiosk = ref.read(kioskActiveProvider);
  final user = kiosk ? ref.read(kioskUserProvider) : null;
  final who =
      (user == null ? null : ref.read(deviceProvider(user))?.name) ??
      (kiosk
          ? l10n.unlockLogPanel
          : ref.read(haPushProvider).value?.deviceName ?? l10n.unlockLogPhone);
  final via = kiosk ? l10n.unlockLogViaPanel : l10n.unlockLogViaPhone;
  final message = switch (command) {
    UnlockDevice() => l10n.unlockLogUnlock(device.name, via),
    DisarmAlarm() => l10n.unlockLogDisarm(device.name, via),
    _ => l10n.unlockLogOpen(device.name, via),
  };
  try {
    await api.callService(
      'logbook',
      'log',
      data: {'name': who, 'message': message, 'entity_id': device.id},
    );
  } on Object catch (e) {
    _log.warning('logbook entry not written', e.runtimeType);
  }
}
