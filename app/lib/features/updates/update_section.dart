import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_info.dart';
import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import 'update_service.dart';

/// "Updates" on the service screen: the opt-in automatic check, a manual
/// check, and installing a new release.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (!ref.watch(updateInstallerProvider).supported) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(updateProvider);
    final updates = ref.read(updateProvider.notifier);
    final status = switch (state) {
      UpdateIdle() => l10n.updateCurrent(appVersion),
      UpdateChecking() => l10n.updateChecking,
      UpdateUpToDate() => l10n.updateUpToDate(appVersion),
      UpdateNoReleases() => l10n.updateNoReleases,
      UpdateAvailable(:final release) => l10n.updateAvailable(release.version),
      UpdateDownloading(:final progress) => l10n.updateDownloading(
        (progress * 100).round(),
      ),
      UpdateInstalling() => l10n.updateInstalling,
      UpdateNeedsPermission() => l10n.updateNeedsPermission,
      UpdateFailed(:final verification) =>
        verification ? l10n.updateRejected : l10n.updateFailed,
    };
    final release = switch (state) {
      UpdateAvailable(:final release) ||
      UpdateNeedsPermission(:final release) => release,
      _ => null,
    };
    return Column(
      key: const Key('updateSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.updateTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(status, key: const Key('updateStatus')),
        if (state is UpdateDownloading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: state.progress),
        ],
        if (release != null && release.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            release.notes.trim(),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (release != null)
              FilledButton.icon(
                key: const Key('updateInstall'),
                onPressed: () => updates.install(release),
                icon: const Icon(Icons.system_update_alt),
                label: Text(l10n.updateInstall),
              ),
            OutlinedButton.icon(
              key: const Key('updateCheck'),
              onPressed:
                  state is UpdateChecking ||
                      state is UpdateDownloading ||
                      state is UpdateInstalling
                  ? null
                  : updates.check,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.updateCheck),
            ),
          ],
        ),
        SwitchListTile(
          key: const Key('updateAuto'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.updateAuto),
          subtitle: Text(l10n.updateAutoHint),
          value: ref.watch(autoUpdateCheckProvider),
          onChanged: (v) => ref.read(autoUpdateCheckProvider.notifier).set(v),
        ),
      ],
    );
  }
}

/// A line on the home screen when a new version is out.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    if (state is! UpdateAvailable) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          key: const Key('updateBanner'),
          leading: Icon(Icons.system_update, color: scheme.onPrimaryContainer),
          title: Text(
            l10n.updateAvailable(state.release.version),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
          onTap: () => context.push(AppRoutes.settingsSection('service')),
        ),
      ),
    );
  }
}
