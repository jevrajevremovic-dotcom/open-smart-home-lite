import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../assist/application/voice_providers.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/controls/alarm_controls.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../house_check/house_check.dart';
import '../../house_check/house_check_screen.dart' show houseCheckStatus;
import 'kiosk_alarm.dart';

/// "I'm leaving": what is still on, open or unlocked, and one button that
/// switches off what the app can and arms the alarm (away).
Future<void> showKioskLeaving(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.6),
  builder: (_) => Theme(data: AppTheme.dark(), child: const _LeavingDialog()),
);

class _LeavingDialog extends ConsumerStatefulWidget {
  const _LeavingDialog();

  @override
  ConsumerState<_LeavingDialog> createState() => _LeavingDialogState();
}

class _LeavingDialogState extends ConsumerState<_LeavingDialog> {
  bool _busy = false;
  bool _done = false;

  Future<void> _go(List<HouseCheckItem> items, SmartHomeDevice? alarm) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    for (final item in items) {
      final fix = item.fix;
      if (fix == null || !mounted) continue;
      await runDeviceCommand(context, ref, item.device, fix);
    }
    final canArm =
        alarm != null &&
        alarm.state.alarmState == AlarmState.disarmed &&
        alarm.limits.alarmArmModes.contains('away');
    if (canArm && mounted) {
      String? code;
      if (alarm.limits.alarmCodeFormat != null &&
          alarm.limits.alarmCodeArmRequired) {
        code = await showAlarmCodeDialog(
          context,
          alarm.limits.alarmCodeFormat!,
        );
      }
      if (mounted &&
          (code != null ||
              alarm.limits.alarmCodeFormat == null ||
              !alarm.limits.alarmCodeArmRequired)) {
        await runDeviceCommand(
          context,
          ref,
          alarm,
          ArmAlarm('away', code: code),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
    final speech = ref.read(speechOutputProvider);
    if (speech.supported) {
      unawaited(
        speech
            .speak(l10n.kioskLeavingBye, languageTag: l10n.localeName)
            .catchError((Object _) => false),
      );
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(houseCheckProvider(HouseCheckMode.leaving));
    final alarm = ref.watch(kioskAlarmProvider);
    final fixable = items.where((i) => i.fix != null).length;
    final manual = items.where(
      (i) => i.fix == null && i.problem != HouseCheckProblem.alarmOff,
    );
    final willArm =
        alarm != null &&
        alarm.state.alarmState == AlarmState.disarmed &&
        alarm.limits.alarmArmModes.contains('away');
    return AlertDialog(
      key: const Key('kioskLeavingDialog'),
      icon: Icon(
        _done ? Icons.waving_hand_outlined : Icons.directions_walk,
        size: 48,
      ),
      title: Text(_done ? l10n.kioskLeavingBye : l10n.kioskLeaving),
      content: SizedBox(
        width: 560,
        child: _done
            ? const SizedBox.shrink()
            : items.isEmpty && !willArm
            ? Text(l10n.kioskLeavingAllGood, style: theme.textTheme.titleMedium)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      ListTile(
                        key: ValueKey('leaving-${item.device.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(DevicePresentation.icon(item.device)),
                        title: Text(item.device.name),
                        subtitle: Text(houseCheckStatus(l10n, item.problem)),
                        trailing: item.fix == null
                            ? null
                            : const Icon(Icons.check_circle_outline),
                      ),
                    if (manual.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.kioskLeavingManual,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: _done
          ? null
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton.icon(
                key: const Key('kioskLeavingGo'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 60),
                  textStyle: theme.textTheme.titleMedium,
                ),
                onPressed: _busy || (fixable == 0 && !willArm)
                    ? null
                    : () => _go(items, alarm),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: Text(
                  willArm
                      ? l10n.kioskLeavingGoArm(fixable)
                      : l10n.kioskLeavingGo(fixable),
                ),
              ),
            ],
    );
  }
}
