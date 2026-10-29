import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../alerts/alert_notifications.dart';
import '../../../app/router/app_router.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/local/local_home.dart';
import '../../devices/presentation/device_edit.dart'
    show DevicePasswordDialog, createRoom;
import '../../kiosk/presentation/kiosk_settings_section.dart';
import '../../app_lock/application/app_lock.dart';
import '../../../core/storage/app_preferences.dart';
import '../../first_run/first_run_controller.dart';
import '../../restricted/application/restricted_mode.dart';
import '../../restricted/presentation/restricted_settings.dart';
import '../data/settings_backup.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/presentation/weather_card.dart';
import '../../shortcuts/quick_tiles_settings.dart';
import 'language_selector.dart';
import '../../simple_mode/simple_mode.dart';
import '../../shortcuts/home_widgets.dart';
import '../../media/now_playing_notification.dart';
import '../../updates/update_section.dart';

/// Settings categories; each one is its own screen (`/settings/<name>`).
enum SettingsSection {
  appearance(Icons.palette_outlined),
  home(Icons.home_outlined),
  kiosk(Icons.tablet_outlined),
  notifications(Icons.notifications_outlined),
  security(Icons.lock_outline),
  privacy(Icons.privacy_tip_outlined),
  backup(Icons.sync_alt),
  about(Icons.info_outline);

  const SettingsSection(this.icon);

  final IconData icon;

  static SettingsSection? tryParse(String? name) =>
      values.where((s) => s.name == name).firstOrNull;

  String title(AppLocalizations l10n) => switch (this) {
    appearance => l10n.appearance,
    home => l10n.settingsHomeSection,
    kiosk => l10n.kioskSection,
    notifications => l10n.settingsNotificationsSection,
    security => l10n.securitySection,
    privacy => l10n.privacySection,
    backup => l10n.backupSection,
    about => l10n.settingsAboutSection,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    appearance => l10n.settingsAppearanceHint,
    home => l10n.settingsHomeHint,
    kiosk => l10n.settingsKioskHint,
    notifications => l10n.settingsNotificationsHint,
    security => l10n.settingsSecurityHint,
    privacy => l10n.settingsPrivacyHint,
    backup => l10n.settingsBackupHint,
    about => l10n.settingsAboutHint,
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
    final notifications = ref.watch(alertNotifierProvider).supported;
    final sections = [
      for (final s in SettingsSection.values)
        if (s != SettingsSection.notifications || notifications) s,
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
                      s.hint(l10n),
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
                SettingsSection.home => _home(context, ref),
                SettingsSection.kiosk => const [KioskSettingsSection()],
                SettingsSection.notifications => _notifications(context, ref),
                SettingsSection.security => _security(context, ref),
                SettingsSection.privacy => _privacy(context, ref),
                SettingsSection.backup => _backup(context, ref),
                SettingsSection.about => const [UpdateSection()],
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

  List<Widget> _home(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final home = ref.watch(localHomeProvider);
    final controller = ref.read(localHomeProvider.notifier);
    final deviceCount = ref.watch(
      visibleDeviceIdsProvider.select((ids) => ids.length),
    );
    final roomCount = ref.watch(roomsProvider.select((r) => r.length));
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.home_outlined),
        title: Text(
          ref.watch(homeSnapshotProvider.select((s) => s.locationName)) ??
              l10n.settingsHomeSection,
        ),
        subtitle: Text(l10n.devicesInRooms(deviceCount, roomCount)),
      ),
      if (home.demo) ...[
        InlineNotice.info(l10n.demoHomeNotice),
        const SizedBox(height: 8),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          key: const Key('settingsAddDevice'),
          onPressed: () => context.push(AppRoutes.addDevice),
          icon: const Icon(Icons.add),
          label: Text(l10n.addDeviceTitle),
        ),
      ),
      if (home.devices.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(l10n.homeDevicesTitle, style: textTheme.labelLarge),
        for (final d in home.devices)
          ListTile(
            key: ValueKey('homeDevice-${d.key}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(switch (d.adapter) {
              'wled' => Icons.light_outlined,
              'tasmota' => Icons.outlet_outlined,
              'esphome' => Icons.memory,
              _ => Icons.power_outlined,
            }),
            title: Text(d.label ?? d.model ?? d.host),
            subtitle: Text([?d.model, d.host].join(' · ')),
            trailing: d.adapter == 'shelly' || d.adapter == 'esphome'
                ? IconButton(
                    key: ValueKey('devicePassword-${d.key}'),
                    tooltip: l10n.devicePasswordChange,
                    icon: Icon(d.secured ? Icons.lock : Icons.lock_open),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DevicePasswordDialog(
                        deviceKey: d.key,
                        isKey: d.adapter == 'esphome',
                      ),
                    ),
                  )
                : null,
          ),
      ],
      const SizedBox(height: 16),
      Text(l10n.navRooms, style: textTheme.labelLarge),
      for (final r in home.rooms)
        ListTile(
          key: ValueKey('homeRoom-${r.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.meeting_room_outlined),
          title: Text(r.name),
          trailing: IconButton(
            key: ValueKey('deleteRoom-${r.id}'),
            tooltip: l10n.roomDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await _confirm(
                context,
                title: l10n.roomDelete,
                body: l10n.roomDeleteConfirm(r.name),
                action: l10n.delete,
                destructive: true,
              )) {
                await controller.removeRoom(r.id);
              }
            },
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('settingsAddRoom'),
          onPressed: () => createRoom(context, ref),
          icon: const Icon(Icons.add),
          label: Text(l10n.roomNew),
        ),
      ),
      const Divider(height: 24),
      SwitchListTile(
        key: const Key('demoDevicesSwitch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.science_outlined),
        title: Text(l10n.demoDevicesSetting),
        subtitle: Text(l10n.demoDevicesHint),
        value: home.demo,
        onChanged: controller.setDemo,
      ),
    ];
  }

  List<Widget> _notifications(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return [
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
    ];
  }

  List<Widget> _backup(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
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
        key: const Key('homeWeatherSwitch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.cloud_outlined),
        title: Text(l10n.weatherHomeLocationSetting),
        subtitle: Text(l10n.weatherHomeLocationSettingHint),
        value: ref.watch(homeLocationWeatherEnabledProvider) != null,
        onChanged: (v) => v
            ? enableHomeLocationWeather(context, ref)
            : ref.read(homeLocationWeatherEnabledProvider.notifier).set(null),
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
    await ref.read(appPreferencesProvider).clear();
    // Back to the first start.
    ref.invalidate(firstRunProvider);
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
