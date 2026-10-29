import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/brand.dart';
import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../alerts/alert_notifications.dart';
import '../app_lock/application/app_lock.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/presentation/device_presentation.dart';
import '../favorites/application/favorites_controller.dart';
import '../ha_notify/ha_push_tile.dart';
import '../settings/application/appearance_controllers.dart';
import '../settings/data/ha_backup.dart';
import 'first_run_controller.dart';

enum _Page { welcome, restore, look, favorites, messages, security, done }

/// Saved copies of the settings in Home Assistant; none when unreachable.
final _backupsProvider = FutureProvider.autoDispose<List<HaBackup>>((
  ref,
) async {
  final service = ref.watch(haBackupServiceProvider);
  if (service == null) return const [];
  try {
    return await service.list();
  } on Object {
    return const [];
  }
});

/// Right after the first sign-in: a few short, skippable pages that set
/// the app up for this household. Everything here is also in Settings.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  int _index = 0;
  bool? _wall;

  bool get _isWall => _wall ?? MediaQuery.sizeOf(context).shortestSide >= 600;

  List<_Page> _pages() {
    final hasBackups = ref.watch(_backupsProvider).value?.isNotEmpty ?? false;
    return [
      _Page.welcome,
      if (hasBackups) _Page.restore,
      if (!_isWall) ...[
        _Page.look,
        _Page.favorites,
        if (ref.watch(alertNotifierProvider).supported) _Page.messages,
        // Only where the device can lock (not on the web).
        if (ref.watch(deviceAuthAvailableProvider).value ?? false)
          _Page.security,
        _Page.done,
      ],
    ];
  }

  Future<void> _finish(String route) async {
    await ref.read(firstRunProvider.notifier).finish();
    if (mounted) context.go(route);
  }

  void _next(List<_Page> pages) {
    if (_index < pages.length - 1) {
      setState(() => _index++);
    } else {
      // A wall panel continues in the installer's checklist (kiosk, PIN).
      _finish(_isWall ? AppRoutes.installerSetup : AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages();
    final index = _index.clamp(0, pages.length - 1);
    final page = pages[index];
    final last = index == pages.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && index > 0) setState(() => _index = index - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(Brand.name(l10n)),
          actions: [
            if (page != _Page.done)
              TextButton(
                key: const Key('firstRunSkip'),
                onPressed: () => _finish(AppRoutes.home),
                child: Text(l10n.firstRunSkip),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (index + 1) / pages.length),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, _) => LinearProgressIndicator(value: v),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    key: ValueKey(page),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: switch (page) {
                          _Page.welcome => _welcome(context),
                          _Page.restore => const _RestorePage(),
                          _Page.look => const _LookPage(),
                          _Page.favorites => const _FavoritesPage(),
                          _Page.messages => _PageBody(
                            icon: Icons.campaign_outlined,
                            title: l10n.firstRunMessagesTitle,
                            body: l10n.firstRunMessagesBody,
                            child: const HaPushTile(),
                          ),
                          _Page.security => const _SecurityPage(),
                          _Page.done => _PageBody(
                            icon: Icons.check_circle_outline,
                            title: l10n.firstRunDoneTitle,
                            body: l10n.firstRunDoneBody,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    if (index > 0)
                      TextButton(
                        key: const Key('firstRunBack'),
                        onPressed: () => setState(() => _index = index - 1),
                        child: Text(l10n.setupBack),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('firstRunNext'),
                      onPressed: () => _next(pages),
                      child: Text(
                        !last
                            ? l10n.setupNext
                            : _isWall
                            ? l10n.firstRunWallNext
                            : l10n.firstRunStart,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final l10n = context.l10n;
    final host = ref.watch(activeProfileProvider)?.address.baseUri.host ?? '';
    Widget role(bool wall, IconData icon, String title, String hint) {
      final selected = _isWall == wall;
      final scheme = Theme.of(context).colorScheme;
      return Card(
        key: Key(wall ? 'firstRunRoleWall' : 'firstRunRolePhone'),
        elevation: 0,
        color: selected ? scheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(icon, size: 32),
          title: Text(title),
          subtitle: Text(hint),
          trailing: selected ? Icon(Icons.check, color: scheme.primary) : null,
          onTap: () => setState(() => _wall = wall),
        ),
      );
    }

    return _PageBody(
      leading: const BrandLogo(size: 64),
      title: l10n.firstRunWelcomeTitle,
      body: l10n.firstRunWelcomeBody(host),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.firstRunRoleQuestion,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          role(
            false,
            Icons.smartphone,
            l10n.firstRunRolePhone,
            l10n.firstRunRolePhoneHint,
          ),
          const SizedBox(height: 8),
          role(
            true,
            Icons.tablet_outlined,
            l10n.firstRunRoleWall,
            l10n.firstRunRoleWallHint,
          ),
        ],
      ),
    );
  }
}

/// A page: an icon, a title, a sentence or two, and its controls.
class _PageBody extends StatelessWidget {
  const _PageBody({
    this.icon,
    this.leading,
    required this.title,
    required this.body,
    this.child,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child:
              leading ?? Icon(icon, size: 40, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (child != null) ...[const SizedBox(height: 24), child!],
      ],
    );
  }
}

class _RestorePage extends ConsumerStatefulWidget {
  const _RestorePage();

  @override
  ConsumerState<_RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends ConsumerState<_RestorePage> {
  String? _restored;

  Future<void> _restore(HaBackup backup) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.haBackupRestoreTitle(backup.name)),
        content: Text(l10n.haBackupRestoreBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('firstRunRestoreConfirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.haBackupRestore),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await restoreHaBackup(ref, backup) && mounted) {
      setState(() => _restored = backup.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final backups = ref.watch(_backupsProvider).value ?? const [];
    final date = DateFormat.yMd(l10n.localeName).add_Hm();
    return _PageBody(
      icon: Icons.settings_backup_restore,
      title: l10n.firstRunRestoreTitle,
      body: l10n.firstRunRestoreBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in backups)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _restored == b.name ? Icons.check_circle : Icons.devices,
                color: _restored == b.name ? Colors.green.shade600 : null,
              ),
              title: Text(b.name),
              subtitle: Text(
                [
                  b.scope == BackupScope.home
                      ? l10n.haBackupScopeHome
                      : l10n.haBackupScopeUser,
                  if (b.savedAt != null) date.format(b.savedAt!.toLocal()),
                ].join(' · '),
              ),
              trailing: _restored == b.name
                  ? null
                  : OutlinedButton(
                      onPressed: () => _restore(b),
                      child: Text(l10n.haBackupRestore),
                    ),
            ),
        ],
      ),
    );
  }
}

class _LookPage extends ConsumerWidget {
  const _LookPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);
    final scheme = Theme.of(context).colorScheme;
    String accentName(AppAccent a) => switch (a) {
      AppAccent.terracotta => l10n.accentTerracotta,
      AppAccent.blue => l10n.accentBlue,
      AppAccent.green => l10n.accentGreen,
      AppAccent.purple => l10n.accentPurple,
      AppAccent.rose => l10n.accentRose,
      AppAccent.teal => l10n.accentTeal,
    };
    return _PageBody(
      icon: Icons.palette_outlined,
      title: l10n.firstRunLookTitle,
      body: l10n.firstRunLookBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ThemeMode>(
            key: const Key('firstRunTheme'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.themeAutoDark),
            value: ref.watch(autoDarkProvider),
            onChanged: (v) => ref.read(autoDarkProvider.notifier).set(v),
          ),
          const SizedBox(height: 8),
          Text(l10n.accentTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in AppAccent.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: accentColor(a) ?? const Color(0xFFB5521B),
                  ),
                  label: Text(accentName(a)),
                  selected: accent == a,
                  selectedColor: scheme.secondaryContainer,
                  onSelected: (_) => ref.read(accentProvider.notifier).set(a),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavoritesPage extends ConsumerWidget {
  const _FavoritesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final rooms = ref.watch(roomsProvider);
    final byRoom = ref.watch(deviceIdsByRoomProvider);
    final favorites = ref.watch(favoritesProvider);

    bool useful(String id) {
      final d = devices[id];
      return d != null &&
          !d.isAuxiliary &&
          !d.kind.isSensor &&
          !d.kind.isRoutine &&
          d.kind != DeviceKind.remote;
    }

    final groups = [
      for (final room in [...rooms.map((r) => (r.id, r.name)), (null, null)])
        (room.$2 ?? l10n.roomNoRoom, [...?byRoom[room.$1]?.where(useful)]),
    ].where((g) => g.$2.isNotEmpty).toList();

    return _PageBody(
      icon: Icons.star_outline,
      title: l10n.firstRunFavoritesTitle,
      body: l10n.firstRunFavoritesBody,
      child: groups.isEmpty
          ? Text(
              devices.isEmpty
                  ? l10n.loadingContent
                  : l10n.firstRunFavoritesNone,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.firstRunFavoritesCount(favorites.length),
                  key: const Key('firstRunFavoritesCount'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                for (final (name, ids) in groups) ...[
                  const SizedBox(height: 16),
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in ids)
                        FilterChip(
                          key: Key('firstRunFav-$id'),
                          avatar: Icon(
                            DevicePresentation.icon(devices[id]!),
                            size: 18,
                          ),
                          label: Text(
                            DevicePresentation.shortName(
                              devices[id]!.name,
                              name,
                            ),
                          ),
                          selected: favorites.contains(id),
                          onSelected: (_) =>
                              ref.read(favoritesProvider.notifier).toggle(id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _SecurityPage extends ConsumerWidget {
  const _SecurityPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lock = ref.watch(appLockSettingsProvider);
    return _PageBody(
      icon: Icons.shield_outlined,
      title: l10n.firstRunSecurityTitle,
      body: l10n.firstRunSecurityBody,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('firstRunLock'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.fingerprint),
            title: Text(l10n.appLockSetting),
            subtitle: Text(l10n.appLockSettingHint),
            value: lock.lockApp,
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
            key: const Key('firstRunCritical'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.lock_person_outlined),
            title: Text(l10n.appLockCriticalSetting),
            subtitle: Text(l10n.appLockCriticalSettingHint),
            value: lock.confirmCritical,
            onChanged: (v) => ref
                .read(appLockSettingsProvider.notifier)
                .update((s) => s.copyWith(confirmCritical: v)),
          ),
        ],
      ),
    );
  }
}
