import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_info.dart';
import '../../app/brand.dart';
import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/logging/app_logger.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../kiosk/application/device_admin.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../updates/update_section.dart';

/// The installer's service screen: what runs where, what went wrong lately,
/// and the panel tools. Never shows a token or password.
class ServiceSection extends ConsumerWidget {
  const ServiceSection({super.key});

  /// One plain-text summary for a support ticket (no secrets: the server
  /// is named by its host only).
  static String diagnostics(
    AppLocalizations l10n, {
    required DeviceInfo device,
    required String? host,
    required String? haVersion,
    required bool connected,
    required int devices,
    required int unavailable,
    required bool kiosk,
  }) {
    final time = DateFormat('yyyy-MM-dd HH:mm:ss');
    return [
      '${Brand.name(l10n)} $appVersion',
      'Device: ${device.manufacturer ?? '?'} ${device.model ?? '?'}, '
          'Android ${device.android ?? '?'} (SDK ${device.sdk ?? '?'})',
      'Package: ${device.package ?? '?'}, device owner: ${device.deviceOwner}',
      'Home Assistant: ${haVersion ?? '?'} at ${host ?? '?'}, '
          'connected: $connected',
      'Devices: $devices, unavailable: $unavailable, kiosk: $kiosk',
      'Recent problems:',
      for (final r in AppLogger.recentProblems.reversed.take(20))
        '  ${time.format(r.time)} ${r.level.name} ${r.tag}: ${r.message}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final device = ref.watch(deviceInfoProvider).value ?? const DeviceInfo();
    final host = ref.watch(activeProfileProvider)?.address.baseUri.host;
    final status = ref.watch(connectionStatusProvider).value;
    final haVersion =
        status?.haVersion ?? ref.watch(serverConfigProvider).value?.version;
    final connected = status?.isConnected ?? false;
    final visible = ref.watch(visibleDeviceIdsProvider);
    final unavailable = ref.watch(
      homeSnapshotProvider.select(
        (s) => visible.where((id) => s.devices[id]?.available == false).length,
      ),
    );
    final kiosk = ref.watch(kioskActiveProvider);
    final problems = AppLogger.recentProblems.reversed.take(10).toList();
    final time = DateFormat.Md(l10n.localeName).add_Hm();

    Widget row(IconData icon, String title, String value, {Key? key}) =>
        ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (Brand.support.isNotEmpty)
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              key: const Key('serviceSupport'),
              leading: Icon(
                Icons.support_agent,
                color: scheme.onPrimaryContainer,
              ),
              title: Text(
                l10n.serviceSupport(Brand.name(l10n)),
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              subtitle: Text(
                Brand.support,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const UpdateSection(),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          key: const Key('serviceSetup'),
          onPressed: () => context.push(AppRoutes.installerSetup),
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: Text(l10n.setupTitle),
        ),
        const SizedBox(height: 8),
        row(
          Icons.apps,
          l10n.serviceApp,
          '${Brand.name(l10n)} $appVersion',
          key: const Key('serviceAppRow'),
        ),
        row(
          Icons.tablet_android_outlined,
          l10n.serviceDevice,
          [
            [?device.manufacturer, ?device.model].join(' '),
            if (device.android != null) 'Android ${device.android}',
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        row(
          Icons.dns_outlined,
          l10n.serviceServer,
          [
            ?host,
            if (haVersion != null) 'Home Assistant $haVersion',
            connected ? l10n.serviceConnected : l10n.serviceDisconnected,
          ].join(' · '),
        ),
        row(
          Icons.devices_other_outlined,
          l10n.serviceDevices,
          l10n.serviceDevicesValue(visible.length, unavailable),
        ),
        row(
          device.deviceOwner ? Icons.verified_user_outlined : Icons.tablet,
          l10n.servicePanel,
          device.deviceOwner ? l10n.servicePanelManaged : l10n.servicePanelNot,
          key: const Key('servicePanelRow'),
        ),
        if (device.deviceOwner) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('servicePanelApply'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await ref
                      .read(deviceAdminProvider)
                      .applyPolicies();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? l10n.servicePanelApplied : l10n.servicePanelFailed,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.home_outlined),
                label: Text(l10n.servicePanelApply),
              ),
              OutlinedButton.icon(
                key: const Key('servicePanelRelease'),
                onPressed: () => _release(context, ref),
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(l10n.servicePanelRelease),
              ),
            ],
          ),
        ],
        ListTile(
          key: const Key('serviceLicenses'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.gavel_outlined),
          title: Text(l10n.serviceLicenses),
          subtitle: Text(l10n.serviceLicensesHint),
          trailing: const Icon(Icons.chevron_right),
          // Every package's licence, as Flutter collects them.
          onTap: () => showLicensePage(
            context: context,
            applicationName: Brand.name(l10n),
            applicationVersion: appVersion,
            applicationLegalese: 'Apache License 2.0',
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.serviceProblems, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (problems.isEmpty)
          Text(
            l10n.serviceNoProblems,
            key: const Key('serviceNoProblems'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          for (final p in problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${time.format(p.time)} · ${p.tag}: ${p.message}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: p.level == LogLevel.error
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('serviceCopy'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(
                  text: diagnostics(
                    l10n,
                    device: device,
                    host: host,
                    haVersion: haVersion,
                    connected: connected,
                    devices: visible.length,
                    unavailable: unavailable,
                    kiosk: kiosk,
                  ),
                ),
              );
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.serviceCopied)),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.serviceCopy),
          ),
        ),
        Text(
          l10n.serviceCopyHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.servicePanelRelease),
        content: Text(l10n.servicePanelReleaseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('servicePanelReleaseConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.servicePanelRelease),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(deviceAdminProvider).release();
    ref.invalidate(deviceInfoProvider);
  }
}
