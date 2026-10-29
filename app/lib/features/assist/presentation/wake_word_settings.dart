import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../clap/clap_platform.dart';
import '../../kiosk/application/kiosk_controller.dart';

/// Hands-free Assist (wake word) in the kiosk settings (Android only).
/// Turning it on first explains where the sound goes.
class WakeWordSettings extends ConsumerWidget {
  const WakeWordSettings({super.key});

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.record_voice_over_outlined),
        title: Text(l10n.wakeWordPrivacyTitle),
        content: SingleChildScrollView(child: Text(l10n.wakeWordPrivacyBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('wakeWordAllow'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.wakeWordAllow),
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
        .update((s) => s.copyWith(wakeWordEnabled: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(clapPlatformProvider).supported) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final enabled = ref.watch(
      kioskSettingsProvider.select((s) => s.wakeWordEnabled),
    );
    return SwitchListTile(
      key: const Key('wakeWordSwitch'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.record_voice_over_outlined),
      title: Text(l10n.wakeWordSetting),
      subtitle: Text(l10n.wakeWordSettingHint),
      value: enabled,
      onChanged: (v) => v
          ? _enable(context, ref)
          : ref
                .read(kioskSettingsProvider.notifier)
                .update((s) => s.copyWith(wakeWordEnabled: false)),
    );
  }
}
