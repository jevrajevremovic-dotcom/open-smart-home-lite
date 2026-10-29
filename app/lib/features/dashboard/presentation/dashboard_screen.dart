import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../application/dashboard_layout.dart';
import '../application/home_sentence.dart';
import '../../extras/air_advice.dart';
import '../../extras/extras_sheet.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../../integrations/home_assistant/websocket/connection_status.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/home_state_repository.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/presentation/all_lights.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/device_grid.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../devices/presentation/stale_data_banner.dart';
import '../../assist/presentation/assist_sheet.dart';
import '../../devices/domain/capability.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../media/application/media_providers.dart';
import '../../media/presentation/media_artwork.dart';
import '../../media/presentation/media_player_view.dart';
import '../../media/presentation/media_sheet.dart';
import '../../notifications/presentation/notifications.dart';
import '../../restricted/application/restricted_mode.dart';
import '../../rooms/presentation/room_card.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/presentation/weather_card.dart';
import '../../todo/todo_screen.dart';
import '../../household/family_messages.dart';
import '../application/home_summaries.dart';

import 'on_now_strip.dart';
import '../../updates/update_section.dart';
import 'weather_sky.dart';
import '../../../app/brand.dart';
import '../../scenes/presentation/scene_colors.dart';
part 'dashboard_summary.dart';
part 'dashboard_sections.dart';

/// Default home screen, generated from the available devices: summary,
/// favorites, scenes, rooms and things that need attention.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        // A faint wash of the sky outside behind the greeting.
        flexibleSpace: const WeatherSky(),
        title: const _HomeSwitcher(),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ConnectionIndicator(),
          ),
        ],
      ),
      // Assist can unlock doors by voice: not in child / guest mode.
      floatingActionButton: ref.watch(restrictedModeProvider).enabled
          ? null
          : FloatingActionButton(
              key: const Key('openAssist'),
              tooltip: context.l10n.assistTitle,
              onPressed: () => showAssist(context),
              child: const Icon(Icons.assistant_outlined),
            ),
      body: const MockModeBanner(child: DashboardBody()),
    );
  }
}

/// The greeting; with several homes, tapping it switches between them.
class _HomeSwitcher extends ConsumerWidget {
  const _HomeSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        ref.watch(homeSnapshotProvider.select((s) => s.locationName)) ??
        ref.watch(serverConfigProvider).value?.locationName ??
        Brand.name(context.l10n);
    final homes = ref.watch(savedHomesProvider).value ?? const [];
    final greeting = DashboardGreeting(
      homeName: title,
      showSwitcher: homes.length > 1,
    );
    if (homes.length < 2) return greeting;
    final active = ref.watch(activeProfileProvider);
    return PopupMenuButton<String>(
      key: const Key('homeSwitcher'),
      tooltip: context.l10n.homesTitle,
      onSelected: (id) {
        final home = homes.firstWhere((h) => h.profile.id == id);
        ref.read(sessionControllerProvider.notifier).switchTo(home.profile);
      },
      itemBuilder: (_) => [
        for (final h in homes)
          CheckedPopupMenuItem(
            key: ValueKey('switchHome-${h.profile.id}'),
            value: h.profile.id,
            checked: h.profile.id == active?.id,
            child: Text(h.name),
          ),
      ],
      child: greeting,
    );
  }
}

/// The home in one sentence under the greeting.
class _HomeSentence extends ConsumerWidget {
  const _HomeSentence();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        ref.watch(homeSentenceProvider(context.l10n)),
        key: const Key('homeSentence'),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Time-of-day greeting and date above the home's name.
class DashboardGreeting extends StatelessWidget {
  const DashboardGreeting({
    super.key,
    required this.homeName,
    this.showSwitcher = false,
  });

  final String homeName;

  /// A small arrow hints that the name opens the home switcher.
  final bool showSwitcher;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      >= 5 && < 12 => l10n.greetingMorning,
      >= 12 && < 18 => l10n.greetingAfternoon,
      >= 18 && < 23 => l10n.greetingEvening,
      _ => l10n.greetingNight,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting · ${DateFormat.MMMEd(l10n.localeName).format(now)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                homeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (showSwitcher) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ],
    );
  }
}

/// Dashboard content, shared by the normal and the kiosk dashboard.
///
/// Narrow or portrait screens get one scrolling column. Large screens and
/// landscape tablets get two panes: status on the left, favorites and rooms
/// on the right, so a wall panel shows everything without scrolling much.
class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, this.kiosk = false});

  /// Kiosk mode hides links that leave the kiosk routes.
  final bool kiosk;

  static const _pad = EdgeInsets.symmetric(horizontal: 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = _firstLoad(ref);
    // Placeholders fade into the real content once the first data arrives.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(loading),
        child: _content(context, ref, loading),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, bool loading) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoPanes =
            width >= Breakpoints.large ||
            (width >= Breakpoints.expanded && width > constraints.maxHeight);
        final refresh = ref.read(webSocketManagerProvider)?.retryNow;
        if (loading) {
          return CustomScrollView(
            slivers: [
              ..._fixedSlivers(ref, progress: false),
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: DashboardSkeleton(label: context.l10n.loadingContent),
                ),
              ),
            ],
          );
        }
        if (!twoPanes) {
          return RefreshIndicator(
            onRefresh: () async => refresh?.call(),
            child: CustomScrollView(
              slivers: [
                ..._fixedSlivers(ref),
                ..._cards(context, ref),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: const Key('dashboardStatusPane'),
              width: width >= Breakpoints.large ? 400 : 340,
              child: CustomScrollView(
                slivers: [
                  ..._fixedSlivers(ref),
                  ..._cards(context, ref, content: false),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => refresh?.call(),
                child: CustomScrollView(
                  slivers: [
                    ..._cards(context, ref, content: true),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Nothing loaded yet and still connecting: placeholders, not empty cards.
  static bool _firstLoad(WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    return !ref.watch(homeSnapshotProvider.select((s) => s.hasData)) &&
        (status == SyncStatus.initial || status == SyncStatus.syncing);
  }

  /// Warnings that always stay on top, whatever the layout.
  List<Widget> _fixedSlivers(WidgetRef ref, {bool progress = true}) {
    final syncing =
        progress && ref.watch(syncStatusProvider) == SyncStatus.syncing;
    return [
      const SliverPadding(
        padding: _pad,
        sliver: SliverToBoxAdapter(child: StaleDataBanner()),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverToBoxAdapter(child: ConnectionProblemCard()),
      ),
      if (syncing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
      const SliverPadding(
        padding: _pad,
        sliver: SliverToBoxAdapter(child: CriticalAlertsBanner()),
      ),
    ];
  }

  /// The slivers of one [card] of the user's layout.
  List<Widget> _card(BuildContext context, WidgetRef ref, DashboardCard card) {
    final l10n = context.l10n;
    Widget box(Widget child) => SliverPadding(
      padding: _pad,
      sliver: SliverToBoxAdapter(child: child),
    );
    switch (card) {
      case DashboardCard.summary:
        return [
          if (!kiosk) box(const UpdateBanner()),
          if (!kiosk) box(const _HomeSentence()),
          if (!kiosk) box(const OnNowStrip(padding: EdgeInsets.only(top: 12))),
          box(const AirAdviceCard(padding: EdgeInsets.only(top: 12))),
          box(const DashboardSummaryRow()),
        ];
      case DashboardCard.weather:
        return [box(WeatherSection(allowDeviceLocation: !kiosk))];
      case DashboardCard.media:
        return [box(const NowPlayingCard())];
      case DashboardCard.notifications:
        return [box(const NotificationsBanner())];
      case DashboardCard.lists:
        if (kiosk) return const [];
        return [
          box(SectionHeader(l10n.dashCardLists)),
          box(const TodoListsCard()),
        ];
      case DashboardCard.shortcuts:
        if (kiosk) return const [];
        return [
          box(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final links = [
                    _QuickLink(
                      key: const Key('openHouseCheck'),
                      onPressed: () => context.push(AppRoutes.houseCheck),
                      icon: Icons.fact_check_outlined,
                      label: l10n.houseCheckShort,
                    ),
                    _QuickLink(
                      key: const Key('openMessages'),
                      onPressed: () => showFamilyMessages(context),
                      icon: Icons.forum_outlined,
                      label: l10n.familyMessages,
                    ),
                    _QuickLink(
                      key: const Key('openEnergy'),
                      onPressed: () => context.push(AppRoutes.energy),
                      icon: Icons.bolt,
                      label: l10n.energyTitle,
                    ),
                    _QuickLink(
                      key: const Key('openCalendar'),
                      onPressed: () => context.push(AppRoutes.calendar),
                      icon: Icons.calendar_month_outlined,
                      label: l10n.calendarTitle,
                    ),
                    _QuickLink(
                      key: const Key('openActivity'),
                      onPressed: () => context.push(AppRoutes.activity),
                      icon: Icons.history,
                      label: l10n.activityTitle,
                    ),
                    _QuickLink(
                      key: const Key('openExtras'),
                      onPressed: () => showExtras(context),
                      icon: Icons.apps,
                      label: l10n.extrasShort,
                    ),
                  ];
                  // Phones and narrow columns: equal buttons, icon over
                  // label, as many per row as fit with every label whole
                  // (five, or three and two with large text).
                  if (WindowSize.fromWidth(constraints.maxWidth) ==
                      WindowSize.compact) {
                    const gap = 8.0;
                    final labels = [for (final l in links) l.label];
                    var perRow = links.length;
                    double width() =>
                        (constraints.maxWidth - gap * (perRow - 1)) / perRow;
                    while (perRow > 2 &&
                        !_labelsFit(context, labels, width() - 16)) {
                      perRow--;
                    }
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final link in links)
                          SizedBox(width: width(), child: link.stacked()),
                      ],
                    );
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, runSpacing: 8, children: links),
                  );
                },
              ),
            ),
          ),
        ];
      case DashboardCard.scenes:
        final sceneIds = ref.watch(
          dashboardSummaryProvider.select((s) => s.sceneIds),
        );
        if (sceneIds.isEmpty) return const [];
        return [
          box(SectionHeader(l10n.scenesTitle)),
          box(SceneButtons(sceneIds: sceneIds)),
        ];
      case DashboardCard.attention:
        return [box(const AttentionSection())];
      case DashboardCard.favorites:
        final favorites = ref.watch(existingFavoritesProvider);
        return [
          box(SectionHeader(l10n.navFavorites)),
          SliverPadding(
            padding: _pad,
            sliver: favorites.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyHint(
                      icon: Icons.star_border,
                      text: l10n.favoritesEmpty,
                      actionLabel: l10n.favoritesBrowse,
                      onAction: () => context.push(AppRoutes.allDevices),
                    ),
                  )
                : DeviceSliverGrid(deviceIds: favorites),
          ),
        ];
      case DashboardCard.rooms:
        final rooms = ref.watch(roomsProvider);
        final hasUnassigned = ref.watch(
          deviceIdsByRoomProvider.select((m) => m.containsKey(null)),
        );
        if (rooms.isEmpty && !hasUnassigned) return const [];
        return [
          box(
            SectionHeader(
              l10n.navRooms,
              trailing: kiosk
                  ? null
                  : TextButton(
                      onPressed: () => context.go(AppRoutes.rooms),
                      child: Text(l10n.allDevices),
                    ),
            ),
          ),
          SliverPadding(
            padding: _pad,
            sliver: RoomSliverGrid(
              rooms: [
                for (final r in rooms) (r.id, r.name, r.icon),
                if (hasUnassigned) (null, l10n.roomNoRoom, null),
              ],
            ),
          ),
        ];
    }
  }

  /// Cards in the user's order; [content] limits them to one side of the
  /// two-pane layout (`null` = all, one column).
  List<Widget> _cards(BuildContext context, WidgetRef ref, {bool? content}) {
    final layout = ref.watch(dashboardLayoutProvider);
    return [
      for (final card in layout.visible)
        if (content == null || card.contentPane == content)
          ..._card(context, ref, card),
    ];
  }
}
