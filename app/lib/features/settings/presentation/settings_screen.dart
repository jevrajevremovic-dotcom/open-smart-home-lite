import 'package:flutter/material.dart';

import '../../installer/service_section.dart';
import 'ha_backup_section.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../alerts/alert_notifications.dart';
import '../../connection/presentation/remote_address.dart';
import '../../ha_notify/ha_push_tile.dart';
import '../../../app/router/app_router.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../kiosk/presentation/kiosk_settings_section.dart';
import '../../app_lock/application/app_lock.dart';
import '../../assist/application/voice_providers.dart';
import '../../restricted/application/restricted_mode.dart';
import '../../restricted/presentation/restricted_settings.dart';
import '../data/settings_backup.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/presentation/weather_card.dart';
import '../../nfc_tags/nfc_tags.dart';
import '../../nfc_tags/nfc_tags_ui.dart';
import '../../shortcuts/quick_tiles_settings.dart';
import '../../assist/presentation/assist_settings.dart';
import 'language_selector.dart';
import '../../simple_mode/simple_mode.dart';
import '../../shortcuts/home_widgets.dart';
import '../../media/now_playing_notification.dart';

/// Settings categories; each one is its own screen (`/settings/<name>`).
enum SettingsSection {
  appearance(Icons.palette_outlined),
  server(Icons.dns_outlined),
  kiosk(Icons.tablet_outlined),
  notifications(Icons.notifications_outlined),
  assist(Icons.assistant_outlined),
  security(Icons.lock_outline),
  nfc(Icons.nfc),
  privacy(Icons.privacy_tip_outlined),
  backup(Icons.sync_alt),
  service(Icons.build_outlined);

  const SettingsSection(this.icon);

  final IconData icon;

  static SettingsSection? tryParse(String? name) =>
      values.where((s) => s.name == name).firstOrNull;

  String title(AppLocalizations l10n) => switch (this) {
    appearance => l10n.appearance,
    server => l10n.serverSection,
    kiosk => l10n.kioskSection,
    notifications => l10n.settingsNotificationsSection,
    assist => l10n.settingsAssistSection,
    security => l10n.securitySection,
    nfc => l10n.nfcTitle,
    privacy => l10n.privacySection,
    backup => l10n.backupSection,
    service => l10n.serviceSection,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    appearance => l10n.settingsAppearanceHint,
    server => l10n.settingsServerHint,
    kiosk => l10n.settingsKioskHint,
    notifications => l10n.settingsNotificationsHint,
    assist => l10n.settingsAssistHint,
    security => l10n.settingsSecurityHint,
    nfc => l10n.nfcSectionHint,
    privacy => l10n.settingsPrivacyHint,
    backup => l10n.settingsBackupHint,
    service => l10n.serviceSectionHint,
  };
}

/// Phones: the list of categories, or one category with a back arrow.
/// Tablets: categories on the left, the selected one on the right.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.section});

  /// `null` = the category list (on tablets: the first category).
  final SettingsSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // Child / guest mode: settings are closed until the PIN is entered.
    if (ref.watch(restrictedModeProvider).enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [RestrictedActiveCard()],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.expanded) {
          final selected = section ?? SettingsSection.appearance;
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(l10n.settingsTitle),
            ),
            body: MockModeBanner(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 340, child: _SectionList(selected: selected)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _SectionBody(
                      key: ValueKey(selected),
                      section: selected,
                      showTitle: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final current = section;
        if (current == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.settingsTitle)),
            body: const MockModeBanner(child: _SectionList()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(current.title(l10n))),
          body: MockModeBanner(child: _SectionBody(section: current)),
        );
      },
    );
  }
}

class _SectionList extends ConsumerWidget {
  const _SectionList({this.selected});

  /// Highlighted on tablets.
  final SettingsSection? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(activeProfileProvider);
    final notifications = ref.watch(alertNotifierProvider).supported;
    final nfc = ref.watch(nfcPlatformProvider).supported;
    final assist =
        ref.watch(speechOutputProvider).supported ||
        ref.watch(assistLaunchProvider).supported;
    final sections = [
      for (final s in SettingsSection.values)
        if ((s != SettingsSection.notifications || notifications) &&
            (s != SettingsSection.nfc || nfc) &&
            (s != SettingsSection.assist || assist))
          s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ConstrainedContent(
          child: Card(
            child: Column(
              children: [
                for (final s in sections)
                  ListTile(
                    key: Key('settingsSection-${s.name}'),
                    selected: s == selected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: theme.colorScheme.primary,
                      child: Icon(s.icon),
                    ),
                    title: Text(s.title(l10n)),
                    subtitle: Text(
                      s == SettingsSection.server && profile != null
                          ? profile.address.toString()
                          : s.hint(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: selected == null
                        ? const Icon(Icons.chevron_right)
                        : null,
                    onTap: () => context.go(AppRoutes.settingsSection(s.name)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({
    super.key,
    required this.section,
    this.showTitle = false,
  });

  final SettingsSection section;

  /// Tablets show the category title above its settings.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    section.title(l10n),
                    style: textTheme.headlineSmall,
                  ),
                ),
              ...switch (section) {
                SettingsSection.appearance => _appearance(context, ref),
                SettingsSection.server => _server(context, ref),
                SettingsSection.kiosk => const [KioskSettingsSection()],
                SettingsSection.notifications => _notifications(context, ref),
                SettingsSection.security => _security(context, ref),
                SettingsSection.assist => const [AssistSettings()],
                SettingsSection.nfc => const [NfcTagsSection()],
                SettingsSection.privacy => _privacy(context, ref),
                SettingsSection.backup => _backup(context, ref),
                SettingsSection.service => const [ServiceSection()],
              },
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _appearance(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Text(l10n.theme, style: textTheme.labelLarge),
      const SizedBox(height: 8),
      const ThemeModeSelector(),
      const AutoDarkTile(),
      const OledTile(),
      const HomeWidgetSettings(),
      const SizedBox(height: 8),
      Text(l10n.accentTitle, style: textTheme.labelLarge),
      const SizedBox(height: 8),
      const AccentSelector(),
      const SizedBox(height: 16),
      Text(l10n.language, style: textTheme.labelLarge),
      const SizedBox(height: 8),
      const LanguageSelector(),
      const SizedBox(height: 8),
      ListTile(
        key: const Key('settingsHomeLayout'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.dashboard_customize_outlined),
        title: Text(l10n.dashLayoutTitle),
        subtitle: Text(l10n.dashLayoutSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.dashboardLayout),
      ),
      const QuickTilesSettings(),
    ];
  }

  List<Widget> _server(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);
    final version = ref.watch(serverConfigProvider).value?.version;
    final deviceCount = ref.watch(
      visibleDeviceIdsProvider.select((ids) => ids.length),
    );
    final roomCount = ref.watch(roomsProvider.select((r) => r.length));
    return [
      if (profile != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            profile.address.isSecure ? Icons.lock_outline : Icons.dns_outlined,
          ),
          title: Text(profile.address.toString()),
          subtitle: Text(
            [
              if (version != null) l10n.serverVersion(version),
              if (deviceCount > 0) l10n.devicesInRooms(deviceCount, roomCount),
            ].join('\n'),
          ),
        ),
      const RemoteAddressTile(),
      ListTile(
        key: const Key('settingsAddDevice'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline),
        title: Text(l10n.addDeviceTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.addDevice),
      ),
      const _HomesList(),
      OutlinedButton.icon(
        key: const Key('signOutButton'),
        onPressed: () => confirmSignOut(context, ref),
        icon: const Icon(Icons.logout),
        label: Text(l10n.signOut),
      ),
    ];
  }

  List<Widget> _notifications(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return [
      const HaPushTile(),
      const NowPlayingNotificationTile(),
      if (ref.watch(alertNotifierProvider).supported)
        SwitchListTile(
          key: const Key('alertNotifySwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(l10n.alertsSetting),
          subtitle: Text(l10n.alertsSettingHint),
          value: ref.watch(alertNotificationsProvider),
          onChanged: (v) async {
            final alerts = ref.read(alertNotificationsProvider.notifier);
            if (!v) return alerts.disable();
            final messenger = ScaffoldMessenger.of(context);
            if (!await alerts.enable()) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.alertsPermissionDenied)),
                );
            }
          },
        ),
    ];
  }

  List<Widget> _security(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return [
      if (ref.watch(deviceAuthAvailableProvider).value ?? false) ...[
        SwitchListTile(
          key: const Key('appLockSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint),
          title: Text(l10n.appLockSetting),
          subtitle: Text(l10n.appLockSettingHint),
          value: ref.watch(appLockSettingsProvider).lockApp,
          onChanged: (v) async {
            // Prove it works before relying on it.
            if (v &&
                !await ref
                    .read(deviceAuthProvider)
                    .authenticate(l10n.appLockReason)) {
              return;
            }
            await ref
                .read(appLockSettingsProvider.notifier)
                .update((s) => s.copyWith(lockApp: v));
          },
        ),
        SwitchListTile(
          key: const Key('appLockCriticalSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lock_person_outlined),
          title: Text(l10n.appLockCriticalSetting),
          subtitle: Text(l10n.appLockCriticalSettingHint),
          value: ref.watch(appLockSettingsProvider).confirmCritical,
          onChanged: (v) => ref
              .read(appLockSettingsProvider.notifier)
              .update((s) => s.copyWith(confirmCritical: v)),
        ),
      ],
      const RestrictedSettingsTile(),
      const Divider(height: 24),
      const SimpleModeSettings(),
      ListTile(
        key: const Key('openPresenceSim'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.nights_stay_outlined),
        title: Text(l10n.presenceTitle),
        subtitle: Text(l10n.presenceHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.presenceSim),
      ),
    ];
  }

  List<Widget> _backup(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      const HaBackupSection(),
      const SizedBox(height: 24),
      Text(l10n.backupFileTitle, style: textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(l10n.backupHint, style: textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('backupCopy'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: SettingsBackup.export(ref)),
              );
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.backupCopied)));
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.backupCopy),
          ),
          OutlinedButton.icon(
            key: const Key('backupPaste'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final text = (await Clipboard.getData('text/plain'))?.text;
              final ok = text != null && await SettingsBackup.import(ref, text);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? l10n.backupImported : l10n.backupInvalid,
                    ),
                  ),
                );
            },
            icon: const Icon(Icons.paste),
            label: Text(l10n.backupPaste),
          ),
        ],
      ),
    ];
  }

  List<Widget> _privacy(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final critical = context.statusColors.critical;
    return [
      if (ref.watch(deviceLocatorProvider).isSupported)
        SwitchListTile(
          key: const Key('deviceWeatherSwitch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.my_location_outlined),
          title: Text(l10n.weatherEnableDevice),
          subtitle: Text(l10n.weatherDeviceSettingHint),
          value: ref.watch(deviceWeatherEnabledProvider),
          onChanged: (v) => v
              ? enableDeviceWeather(context, ref)
              : ref.read(deviceWeatherEnabledProvider.notifier).set(false),
        ),
      SwitchListTile(
        key: const Key('voiceCloudSwitch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.mic_none),
        title: Text(l10n.voiceCloudSetting),
        subtitle: Text(l10n.voiceCloudSettingHint),
        value: ref.watch(voiceCloudAllowedProvider) ?? false,
        onChanged: (v) => ref.read(voiceCloudAllowedProvider.notifier).set(v),
      ),
      SwitchListTile(
        key: const Key('homeWeatherSwitch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.cloud_outlined),
        title: Text(l10n.weatherHomeLocationSetting),
        subtitle: Text(l10n.weatherHomeLocationSettingHint),
        value: ref.watch(homeLocationWeatherEnabledProvider),
        onChanged: (v) => v
            ? enableHomeLocationWeather(context, ref)
            : ref.read(homeLocationWeatherEnabledProvider.notifier).set(false),
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => confirmDeleteAll(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: critical,
          side: BorderSide(color: critical),
        ),
        icon: const Icon(Icons.delete_forever_outlined),
        label: Text(l10n.deleteAllData),
      ),
    ];
  }
}

Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final ok = await _confirm(
    context,
    title: l10n.signOutConfirmTitle,
    body: l10n.signOutConfirmBody,
    action: l10n.signOut,
  );
  if (ok) await ref.read(sessionControllerProvider.notifier).signOut();
}

Future<void> confirmDeleteAll(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final ok = await _confirm(
    context,
    title: l10n.deleteAllConfirmTitle,
    body: l10n.deleteAllConfirmBody,
    action: l10n.delete,
    destructive: true,
  );
  if (ok) {
    await ref.read(sessionControllerProvider.notifier).deleteAllLocalData();
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.statusColors;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDialogAction'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.critical,
                    foregroundColor: colors.onCritical,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Saved homes (several Home Assistant servers): switch or add one.
class _HomesList extends ConsumerWidget {
  const _HomesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final homes = ref.watch(savedHomesProvider).value ?? const [];
    final active = ref.watch(activeProfileProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (homes.length > 1) ...[
          Text(l10n.homesTitle, style: Theme.of(context).textTheme.labelLarge),
          for (final h in homes)
            ListTile(
              key: ValueKey('home-${h.profile.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                h.profile.id == active?.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(h.name),
              subtitle: Text(h.profile.address.host),
              onTap: h.profile.id == active?.id
                  ? null
                  : () => ref
                        .read(sessionControllerProvider.notifier)
                        .switchTo(h.profile),
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('addHome'),
            onPressed: () {
              ref.read(addingHomeProvider.notifier).set(true);
              context.go(AppRoutes.connectServer);
            },
            icon: const Icon(Icons.add_home_outlined),
            label: Text(l10n.addHome),
          ),
        ),
      ],
    );
  }
}
