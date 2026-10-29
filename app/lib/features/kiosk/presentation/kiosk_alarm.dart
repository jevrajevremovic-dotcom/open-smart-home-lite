import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/controls/alarm_controls.dart';

/// The home's alarm panel (the first one, by name), if there is one.
final kioskAlarmProvider = Provider<SmartHomeDevice?>((ref) {
  final alarms =
      ref
          .watch(homeSnapshotProvider.select((s) => s.devices))
          .values
          .where((d) => d.kind == DeviceKind.alarm && !d.isAuxiliary)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  return alarms.firstOrNull;
});

/// Arm / disarm from the wall: the alarm controls, large, with the keypad
/// for the code (never stored).
Future<void> showKioskAlarm(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.6),
  builder: (_) => const _KioskAlarmDialog(),
);

class _KioskAlarmDialog extends ConsumerWidget {
  const _KioskAlarmDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alarm = ref.watch(kioskAlarmProvider);
    final theme = AppTheme.dark();
    return Theme(
      data: theme.copyWith(
        // Big targets on a wall tablet.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(180, 64),
            textStyle: theme.textTheme.titleMedium,
          ),
        ),
      ),
      child: AlertDialog(
        key: const Key('kioskAlarmDialog'),
        title: Text(alarm?.name ?? l10n.alarmArmTitle),
        content: SizedBox(
          width: 520,
          child: alarm == null
              ? const SizedBox.shrink()
              : AlarmControls(device: alarm),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }
}
