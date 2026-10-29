import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/smart_home_device.dart';
import '../device_actions.dart';
import '../device_presentation.dart';

String alarmModeLabel(AppLocalizations l10n, String mode) => switch (mode) {
  'home' => l10n.alarmArm_home,
  'away' => l10n.alarmArm_away,
  'night' => l10n.alarmArm_night,
  'vacation' => l10n.alarmArm_vacation,
  _ => l10n.alarmArm_custom_bypass,
};

IconData _modeIcon(String mode) => switch (mode) {
  'home' => Icons.home_outlined,
  'away' => Icons.directions_walk,
  'night' => Icons.bedtime_outlined,
  'vacation' => Icons.luggage_outlined,
  _ => Icons.tune,
};

/// Alarm panel: state, arm modes and disarm, with a keypad for the code.
class AlarmControls extends ConsumerWidget {
  const AlarmControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = context.statusColors;
    final d = device;
    final state = d.state.alarmState;
    final armed = state != null && state != AlarmState.disarmed;
    final triggered = state == AlarmState.triggered;
    final color = triggered
        ? status.critical
        : armed
        ? theme.colorScheme.primary
        : status.ok;
    final needsCode = d.limits.alarmCodeFormat != null;

    Future<void> arm(String mode) async {
      String? code;
      if (needsCode && d.limits.alarmCodeArmRequired) {
        code = await showAlarmCodeDialog(context, d.limits.alarmCodeFormat!);
        if (code == null || !context.mounted) return;
      }
      await runDeviceCommand(context, ref, d, ArmAlarm(mode, code: code));
    }

    Future<void> disarm() async {
      String? code;
      if (needsCode) {
        code = await showAlarmCodeDialog(context, d.limits.alarmCodeFormat!);
        if (code == null || !context.mounted) return;
      }
      await runDeviceCommand(context, ref, d, DisarmAlarm(code: code));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Row(
            children: [
              Icon(
                triggered
                    ? Icons.notification_important
                    : armed
                    ? Icons.shield
                    : Icons.shield_outlined,
                size: 40,
                color: color,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  DevicePresentation.status(l10n, d),
                  key: const Key('alarmState'),
                  style: theme.textTheme.titleLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (armed && d.supports(Capability.disarm))
          FilledButton.icon(
            key: const Key('alarmDisarm'),
            onPressed: d.available ? disarm : null,
            icon: const Icon(Icons.lock_open),
            label: Text(l10n.alarmDisarm),
          )
        else if (d.supports(Capability.arm)) ...[
          Text(l10n.alarmArmTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in d.limits.alarmArmModes)
                FilledButton.tonalIcon(
                  key: ValueKey('alarmArm-$mode'),
                  onPressed: d.available ? () => arm(mode) : null,
                  icon: Icon(_modeIcon(mode)),
                  label: Text(alarmModeLabel(l10n, mode)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Asks for the alarm code: a big keypad for numeric codes (good on a wall
/// tablet), a hidden text field otherwise. The code is never stored.
Future<String?> showAlarmCodeDialog(BuildContext context, String format) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AlarmCodeDialog(numeric: format == 'number'),
    );

class _AlarmCodeDialog extends StatefulWidget {
  const _AlarmCodeDialog({required this.numeric});

  final bool numeric;

  @override
  State<_AlarmCodeDialog> createState() => _AlarmCodeDialogState();
}

class _AlarmCodeDialogState extends State<_AlarmCodeDialog> {
  final _text = TextEditingController();
  String _code = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = widget.numeric ? _code : _text.text;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 72,
        height: 60,
        child: FilledButton.tonal(
          key: ValueKey('alarmKey-$label'),
          onPressed: onTap ?? () => setState(() => _code += label),
          child: icon == null
              ? Text(label, style: theme.textTheme.titleLarge)
              : Icon(icon),
        ),
      ),
    );
    return AlertDialog(
      title: Text(l10n.alarmCodeTitle),
      content: widget.numeric
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '•' * _code.length,
                  key: const Key('alarmCodeDots'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final k in row) key(k)],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 80),
                    key('0'),
                    key(
                      'del',
                      icon: Icons.backspace_outlined,
                      onTap: () => setState(() {
                        if (_code.isNotEmpty) {
                          _code = _code.substring(0, _code.length - 1);
                        }
                      }),
                    ),
                  ],
                ),
              ],
            )
          : TextField(
              key: const Key('alarmCodeText'),
              controller: _text,
              obscureText: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('alarmCodeOk'),
          onPressed: value.isEmpty
              ? null
              : () => Navigator.of(context).pop(value),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
