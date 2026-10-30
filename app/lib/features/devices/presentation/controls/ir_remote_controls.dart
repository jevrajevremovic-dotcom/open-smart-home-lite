import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../restricted/application/restricted_mode.dart';
import '../../application/device_providers.dart';
import '../../data/local/broadlink.dart';
import '../../data/local/local_home.dart';
import '../../domain/device_command.dart';
import '../../domain/device_kind.dart';
import '../device_actions.dart';

/// An infrared blaster's learned buttons (each sends its code) and,
/// outside restricted mode, learning new ones from the original remote.
class IrRemoteControls extends ConsumerWidget {
  const IrRemoteControls({super.key, required this.remoteId});

  final String remoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final remote = ref.watch(deviceProvider(remoteId));
    final key = remote?.deviceId;
    if (remote == null || key == null) return const SizedBox.shrink();
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final buttons =
        devices.values
            .where((d) => d.deviceId == key && d.kind == DeviceKind.button)
            .toList()
          ..sort((a, b) => a.sourceId.compareTo(b.sourceId));
    final restricted = ref.watch(restrictedModeProvider).enabled;
    final config = ref
        .watch(localHomeProvider)
        .devices
        .where((d) => d.key == key)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.irButtonsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (buttons.isEmpty) Text(l10n.irButtonsEmpty),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in buttons)
              InputChip(
                key: ValueKey('irButton-${b.id}'),
                label: Text(b.sourceId),
                avatar: const Icon(Icons.settings_remote, size: 18),
                tooltip: l10n.irSend,
                onPressed: () =>
                    runDeviceCommand(context, ref, b, const Activate()),
                onDeleted: restricted || config == null
                    ? null
                    : () => ref.read(localHomeProvider.notifier).setOptions(
                        key,
                        {'btn:${b.sourceId}': ''},
                      ),
                deleteButtonTooltipMessage: l10n.irDelete,
              ),
          ],
        ),
        if (!restricted && config != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('irLearn'),
              onPressed: () => _learn(context, ref, config),
              icon: const Icon(Icons.add),
              label: Text(l10n.irLearn),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _learn(
    BuildContext context,
    WidgetRef ref,
    ConfiguredDevice config,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final learned = await showDialog<_Learned>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LearnDialog(config: config, name: name.trim()),
    );
    if (learned == null) return; // cancelled
    final code = learned.code;
    if (code == null) {
      say(l10n.irLearnFailed);
      return;
    }
    await ref.read(localHomeProvider.notifier).setOptions(config.key, {
      'btn:${name.trim()}': base64.encode(code),
    });
    say(l10n.irLearned(name.trim()));
  }
}

/// What learning gave: the code, or `null` when nothing was heard.
typedef _Learned = ({List<int>? code});

/// Puts the device in learning mode and closes with what it heard.
class _LearnDialog extends ConsumerStatefulWidget {
  const _LearnDialog({required this.config, required this.name});

  final ConfiguredDevice config;
  final String name;

  @override
  ConsumerState<_LearnDialog> createState() => _LearnDialogState();
}

class _LearnDialogState extends ConsumerState<_LearnDialog> {
  @override
  void initState() {
    super.initState();
    () async {
      List<int>? code;
      try {
        code = await ref
            .read(broadlinkClientProvider)
            .session(widget.config)
            .learn();
      } on AppFailure {
        code = null;
      }
      if (mounted) Navigator.of(context).pop((code: code));
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('irLearning'),
      title: Text(widget.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.irLearnPress),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.irLearn),
      content: TextField(
        key: const Key('irLearnName'),
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.irLearnName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('irLearnNameOk'),
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l10n.irLearn),
        ),
      ],
    );
  }
}
