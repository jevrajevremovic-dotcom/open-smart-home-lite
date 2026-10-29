import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../devices/application/device_providers.dart';
import '../kiosk/application/kiosk_controller.dart';
import 'clap_detector.dart';
import 'clap_listener.dart';
import 'clap_platform.dart';

/// Double-clap options in the kiosk settings (Android only).
class ClapSettings extends ConsumerWidget {
  const ClapSettings({super.key});

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mic_none),
        title: Text(l10n.clapPrivacyTitle),
        content: Text(l10n.clapPrivacyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('clapAllow'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clapAllow),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await ref.read(clapPlatformProvider).requestPermission()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.clapPermissionDenied)));
      return;
    }
    await ref
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(clapEnabled: true));
  }

  Future<void> _pickTarget(BuildContext context, WidgetRef ref) async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => const _ClapTargetPicker(),
    );
    if (id == null) return;
    await ref
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(clapTargetId: id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(clapPlatformProvider).supported) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final settings = ref.watch(kioskSettingsProvider);
    final controller = ref.read(kioskSettingsProvider.notifier);
    final target = settings.clapTargetId == null
        ? null
        : ref.watch(deviceProvider(settings.clapTargetId!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('clapSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.sign_language_outlined),
          title: Text(l10n.clapSetting),
          subtitle: Text(l10n.clapSettingHint),
          value: settings.clapEnabled,
          onChanged: (v) => v
              ? _enable(context, ref)
              : controller.update((s) => s.copyWith(clapEnabled: false)),
        ),
        if (settings.clapEnabled) ...[
          ListTile(
            key: const Key('clapTarget'),
            contentPadding: const EdgeInsets.only(left: 40),
            leading: Icon(clapTargetIcon(target)),
            title: Text(l10n.clapTarget),
            subtitle: Text(clapTargetLabel(l10n, target)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTarget(context, ref),
          ),
          ListTile(
            contentPadding: const EdgeInsets.only(left: 40),
            title: Text(l10n.clapSensitivity),
            trailing: DropdownButton<ClapSensitivity>(
              key: const Key('clapSensitivity'),
              value: settings.clapSensitivity,
              onChanged: (v) => v == null
                  ? null
                  : controller.update((s) => s.copyWith(clapSensitivity: v)),
              items: [
                for (final (s, label) in [
                  (ClapSensitivity.low, l10n.clapLow),
                  (ClapSensitivity.medium, l10n.clapMedium),
                  (ClapSensitivity.high, l10n.clapHigh),
                ])
                  DropdownMenuItem(value: s, child: Text(label)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ClapTargetPicker extends ConsumerStatefulWidget {
  const _ClapTargetPicker();

  @override
  ConsumerState<_ClapTargetPicker> createState() => _ClapTargetPickerState();
}

class _ClapTargetPickerState extends ConsumerState<_ClapTargetPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final q = _query.trim().toLowerCase();
    final list =
        devices.values
            .where((d) => isClapTarget(d) && d.name.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: Text(l10n.clapTarget),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                key: const Key('clapSearch'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.clapSearch,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final d in list)
                    ListTile(
                      key: ValueKey('clapPick-${d.id}'),
                      leading: Icon(clapTargetIcon(d)),
                      title: Text(d.name),
                      subtitle: Text(
                        clapTargetLabel(l10n, d).substring(d.name.length + 3),
                      ),
                      onTap: () => Navigator.of(context).pop(d.id),
                    ),
                ],
              ),
            ),
          ],
        ),
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
