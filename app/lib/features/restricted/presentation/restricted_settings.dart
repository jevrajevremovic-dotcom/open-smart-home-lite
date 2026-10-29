import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/security/pin_hasher.dart';
import '../../kiosk/presentation/pin_dialog.dart';
import '../application/restricted_mode.dart';

/// Shown instead of the settings while the mode is on.
class RestrictedActiveCard extends ConsumerWidget {
  const RestrictedActiveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const Key('restrictedActive'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.child_care, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.restrictedActive,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('restrictedDisable'),
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => PinEntryDialog(
                  title: l10n.kioskEnterPin,
                  onSubmit: (pin) async =>
                      await ref
                          .read(restrictedModeProvider.notifier)
                          .disable(pin)
                      ? null
                      : l10n.kioskWrongPin,
                ),
              ),
              icon: const Icon(Icons.lock_open),
              label: Text(l10n.restrictedDisable),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry in Settings → Security.
class RestrictedSettingsTile extends StatelessWidget {
  const RestrictedSettingsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    key: const Key('restrictedSettings'),
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.child_care),
    title: Text(context.l10n.restrictedTitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _RestrictedSetupScreen()),
    ),
  );
}

class _RestrictedSetupScreen extends ConsumerWidget {
  const _RestrictedSetupScreen();

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    String? first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => PinEntryDialog(
        title: l10n.kioskSetPin,
        helper: l10n.kioskPinHint,
        onSubmit: (pin) async {
          if (!PinHasher.validPin.hasMatch(pin)) return l10n.kioskPinInvalid;
          first = pin;
          return null;
        },
      ),
    );
    if (ok != true || first == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PinEntryDialog(
        title: l10n.kioskPinConfirm,
        onSubmit: (pin) async {
          if (pin != first) return l10n.kioskPinMismatch;
          await ref.read(restrictedModeProvider.notifier).enable(pin);
          return null;
        },
      ),
    );
    if (confirmed == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(restrictedModeProvider);
    final controller = ref.read(restrictedModeProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.restrictedTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.restrictedHint),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('restrictedHideSecurity'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.restrictedHideSecurity),
            value: s.hideSecurity,
            onChanged: (v) => controller.setOptions(hideSecurity: v),
          ),
          SwitchListTile(
            key: const Key('restrictedHideCameras'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.restrictedHideCameras),
            value: s.hideCameras,
            onChanged: (v) => controller.setOptions(hideCameras: v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('restrictedEnable'),
            onPressed: () => _enable(context, ref),
            icon: const Icon(Icons.child_care),
            label: Text(l10n.restrictedEnable),
          ),
        ],
      ),
    );
  }
}
