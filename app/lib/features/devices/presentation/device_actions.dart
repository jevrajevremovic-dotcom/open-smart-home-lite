import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../app_lock/application/app_lock.dart';
import '../../extras/unlock_log.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../kiosk/presentation/pin_dialog.dart';
import '../application/device_command_service.dart';
import '../domain/device_command.dart';
import '../domain/smart_home_device.dart';

/// Runs [command] from the UI: asks for confirmation when the command is
/// critical, then reports failures in a snack bar. Returns `true` when the
/// command was accepted by the server.
Future<bool> runDeviceCommand(
  BuildContext context,
  WidgetRef ref,
  SmartHomeDevice device,
  DeviceCommand command,
) async {
  final service = ref.read(deviceCommandServiceProvider);
  if (service == null) return false;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);

  var confirmed = false;
  if (command.isCritical(device)) {
    confirmed = await _confirmCritical(context, device, command);
    if (!confirmed) return false;
    // On the wall panel anyone passing by can tap: the kiosk PIN too.
    if (ref.read(kioskActiveProvider) &&
        context.mounted &&
        !await confirmKioskPin(context, ref)) {
      return false;
    }
    // Optional second factor: fingerprint / face / device PIN.
    if (ref.read(appLockSettingsProvider).confirmCritical &&
        await ref.read(deviceAuthProvider).isAvailable()) {
      final passed = await ref
          .read(deviceAuthProvider)
          .authenticate(l10n.appLockCriticalReason(device.name));
      if (!passed) return false;
    }
  }
  // A tap the hand can feel: every command from the UI (sliders tick on
  // their own). Android's "touch feedback" setting turns it off.
  unawaited(
    command.isCritical(device)
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.lightImpact(),
  );
  try {
    await service.execute(device, command, confirmed: confirmed);
    // Who did it, in Home Assistant's logbook.
    if (confirmed) {
      unawaited(logCriticalAction(ref, l10n, device, command));
    }
    return true;
  } on AppFailure catch (failure) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
    return false;
  }
}

Future<bool> _confirmCritical(
  BuildContext context,
  SmartHomeDevice device,
  DeviceCommand command,
) async {
  final l10n = context.l10n;
  final title = switch (command) {
    UnlockDevice() => l10n.confirmUnlockTitle(device.name),
    DisarmAlarm() => l10n.confirmDisarmTitle(device.name),
    _ => l10n.confirmOpenTitle(device.name),
  };
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.statusColors;
      return AlertDialog(
        icon: const Icon(Icons.gpp_maybe_outlined),
        title: Text(title),
        content: Text(context.l10n.confirmCriticalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmCriticalAction'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: colors.onWarning,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
