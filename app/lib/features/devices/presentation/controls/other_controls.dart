import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../domain/capability.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../../domain/smart_home_device.dart';
import '../../../authentication/application/session_controller.dart';
import '../../../automations/domain/simple_automation.dart';
import '../../../automations/presentation/automation_editor_screen.dart';
import '../../../kiosk/application/kiosk_controller.dart';
import '../../../restricted/application/restricted_mode.dart';
import '../../../media/presentation/media_player_view.dart';
import '../device_actions.dart';
import '../device_presentation.dart';
import 'command_slider.dart';

/// Blinds, curtains, garage doors and valves.
class CoverControls extends ConsumerWidget {
  const CoverControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = device.available;
    Future<void> send(DeviceCommand c) =>
        runDeviceCommand(context, ref, device, c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (device.supports(Capability.open))
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? () => send(const OpenCover()) : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: Text(l10n.open),
                ),
              ),
            if (device.supports(Capability.stop)) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => send(const StopCover()) : null,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.stop),
                ),
              ),
            ],
            if (device.supports(Capability.close)) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? () => send(const CloseCover()) : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: Text(l10n.close),
                ),
              ),
            ],
          ],
        ),
        if (device.supports(Capability.position)) ...[
          const SizedBox(height: 16),
          CommandSlider(
            label: l10n.position,
            value: device.state.position?.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            enabled: enabled,
            format: (v) => '${v.round()} %',
            onCommit: (v) => send(SetCoverPosition(v.round())),
          ),
        ],
      ],
    );
  }
}

class LockControls extends ConsumerWidget {
  const LockControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = device.available;
    final locked = device.state.lockState == DoorLockState.locked;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('lockButton'),
            onPressed: enabled && !locked
                ? () =>
                      runDeviceCommand(context, ref, device, const LockDevice())
                : null,
            icon: const Icon(Icons.lock),
            label: Text(l10n.lock),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('unlockButton'),
            onPressed: enabled && locked
                ? () => runDeviceCommand(
                    context,
                    ref,
                    device,
                    const UnlockDevice(),
                  )
                : null,
            icon: const Icon(Icons.lock_open),
            label: Text(l10n.unlock),
          ),
        ),
      ],
    );
  }
}

/// Large reading for sensors and meters.
class SensorReadout extends StatelessWidget {
  const SensorReadout({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          DevicePresentation.status(l10n, device),
          key: const Key('sensorValue'),
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Scenes, scripts, buttons and automations.
Future<void> _editAutomation(
  BuildContext context,
  WidgetRef ref,
  SmartHomeDevice device,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final id = device.metadata.configId!;
  try {
    final config = await ref
        .read(homeAssistantApiProvider)!
        .fetchAutomation(id);
    final simple = SimpleAutomation.tryParse(config);
    if (simple == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoTooComplex)));
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AutomationEditorScreen(existingId: id, initial: simple),
      ),
    );
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.autoSaveFailed)));
  }
}

Future<void> _deleteAutomation(
  BuildContext context,
  WidgetRef ref,
  SmartHomeDevice device,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        device.kind == DeviceKind.scene ? l10n.sceneDelete : l10n.autoDelete,
      ),
      content: Text(l10n.autoDeleteConfirm(device.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirmDeleteAutomation'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.autoDelete),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final api = ref.read(homeAssistantApiProvider);
  try {
    final id = device.metadata.configId!;
    await (device.kind == DeviceKind.scene
        ? api?.deleteScene(id)
        : api?.deleteAutomation(id));
    if (navigator.canPop()) navigator.pop();
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l10n.autoSaveFailed)));
  }
}

class RoutineControls extends ConsumerWidget {
  const RoutineControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = device.available;
    final isAutomation = device.kind == DeviceKind.automation;
    final last = device.state.lastTriggered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAutomation) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.automationEnabled),
            value: device.state.isOn ?? false,
            onChanged: enabled
                ? (v) => runDeviceCommand(
                    context,
                    ref,
                    device,
                    v ? const TurnOn() : const TurnOff(),
                  )
                : null,
          ),
          Text(
            last == null
                ? l10n.neverTriggered
                : l10n.lastTriggered(formatDateTime(l10n.localeName, last)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (device.supports(Capability.trigger))
          FilledButton.icon(
            key: const Key('activateButton'),
            onPressed: enabled
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await runDeviceCommand(
                      context,
                      ref,
                      device,
                      const Activate(),
                    );
                    if (ok) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.sceneActivated(device.name)),
                        ),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(isAutomation ? l10n.runNow : l10n.activate),
          ),
        // UI-made automations can be deleted (not in kiosk / child mode).
        if ((isAutomation || device.kind == DeviceKind.scene) &&
            device.metadata.configId != null &&
            !ref.watch(kioskActiveProvider) &&
            !ref.watch(restrictedModeProvider).enabled) ...[
          const SizedBox(height: 12),
          if (isAutomation)
            OutlinedButton.icon(
              key: const Key('editAutomation'),
              onPressed: () => _editAutomation(context, ref, device),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.autoEdit),
            ),
          TextButton.icon(
            key: const Key('deleteAutomation'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deleteAutomation(context, ref, device),
            icon: const Icon(Icons.delete_outline),
            label: Text(isAutomation ? l10n.autoDelete : l10n.sceneDelete),
          ),
        ],
      ],
    );
  }
}

/// The player (artwork, seek bar, transport, volume, source).
class MediaControls extends StatelessWidget {
  const MediaControls({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context) => MediaPlayerView(device: device);
}
