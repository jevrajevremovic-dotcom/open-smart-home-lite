import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../assist/presentation/assist_sheet.dart';
import '../../authentication/application/session_controller.dart';
import '../../cameras/application/camera_providers.dart';
import '../../cameras/presentation/camera_view.dart';
import '../../calendar/presentation/calendar_browser.dart';
import '../../calendar/presentation/calendar_widgets.dart';
import '../../dashboard/application/home_sentence.dart';
import '../../dashboard/presentation/dashboard_screen.dart'
    show ConnectionProblemCard, CriticalAlertsBanner, NowPlayingCard;
import '../../devices/presentation/stale_data_banner.dart';
import '../../todo/todo_lists.dart';
import '../../todo/todo_screen.dart' show TodoListsCard;
import '../../weather/presentation/weather_card.dart';
import '../../dashboard/application/home_summaries.dart';
import '../../dashboard/presentation/on_now_strip.dart';
import '../../devices/application/device_groups.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_actions.dart';
import '../../devices/presentation/big_slider.dart';
import '../../devices/presentation/device_history.dart';
import '../../devices/presentation/device_detail_screen.dart'
    show deviceControlsFor;
import '../../devices/presentation/device_presentation.dart';
import '../../energy/application/energy_providers.dart';
import '../../energy/data/energy_repository.dart';
import '../../energy/presentation/energy_format.dart';
import '../../household/application/household_providers.dart';
import '../../household/family_messages.dart';
import '../../household/presentation/person_avatar.dart';
import '../../rooms/presentation/room_look.dart';
import '../../rooms/presentation/room_photo.dart';
import '../../timers/kiosk_timers.dart';
import '../../extras/air_advice.dart';
import '../../extras/celebrations.dart';
import '../../extras/extras_sheet.dart';
import '../../scenes/presentation/scene_colors.dart';
import '../application/kiosk_controller.dart';
import '../application/kiosk_people.dart';
import '../data/kiosk_settings.dart';
import 'kiosk_alarm.dart';
import 'kiosk_bundle_detail.dart';
import 'kiosk_leaving.dart';
import 'kiosk_media_panel.dart';
import 'kiosk_quick_controls.dart';
import '../application/kiosk_now.dart';
import '../../dashboard/presentation/weather_sky.dart';
import 'kiosk_motion.dart';
import 'pin_dialog.dart';
import 'thermostat_dial.dart';
import '../../../app/brand.dart';
import '../../floor_plan/floor_plan.dart';

/// Chosen in the left column for the devices without a room (`null` is
/// the home overview).
const kioskNoRoom = '__no_room__';

/// The area id behind a [kioskColumnsRoomProvider] value (`null` for
/// [kioskNoRoom]: Home Assistant's "no area").
String? _areaOf(String roomId) => roomId == kioskNoRoom ? null : roomId;

/// Room shown in the middle column (`null` = the home overview).
class KioskColumnsRoom extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void select(String? roomId) => state = roomId;
}

final kioskColumnsRoomProvider = NotifierProvider<KioskColumnsRoom, String?>(
  KioskColumnsRoom.new,
);

/// Device shown in the right column (`null` = the room's first climate
/// device, light or other device).
class KioskColumnsDevice extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void select(String? deviceId) => state = deviceId;
}

final kioskColumnsDeviceProvider =
    NotifierProvider<KioskColumnsDevice, String?>(KioskColumnsDevice.new);

/// This week's energy, by day, for the right column (refreshed hourly).
final _weekEnergyProvider = FutureProvider.autoDispose<EnergyReport?>((
  ref,
) async {
  final timer = Timer(const Duration(hours: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final prefs = await ref.watch(energyPrefsProvider.future);
  final repository = ref.watch(energyRepositoryProvider);
  if (prefs == null || repository == null) return null;
  return repository.loadReport(prefs, EnergyRange.week, now: DateTime.now());
});

/// The "columns" kiosk (like a tablet home app): home, rooms, scenes and
/// automations on the left; the home overview (weather, music, calendar,
/// lists) or the chosen room's devices in the middle; the chosen device's
/// controls on the right. Follows the app's light or dark theme. Left
/// alone, it goes back to the home overview.
class KioskColumnsLayout extends ConsumerStatefulWidget {
  const KioskColumnsLayout({super.key});

  @override
  ConsumerState<KioskColumnsLayout> createState() => _KioskColumnsLayoutState();
}

class _KioskColumnsLayoutState extends ConsumerState<KioskColumnsLayout> {
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  /// Direction of the last swipe (1 = to the next room), for the slide.
  double _direction = 1;

  void _step(List<String?> order, String? current, int by) {
    final i = order.indexOf(current);
    final next = i + by;
    if (i < 0 || next < 0 || next >= order.length) return;
    setState(() => _direction = by.toDouble());
    ref.read(kioskColumnsRoomProvider.notifier).select(order[next]);
    ref.read(kioskColumnsDeviceProvider.notifier).select(null);
  }

  void _touched() {
    _idle?.cancel();
    final after = ref.read(kioskSettingsProvider).returnHomeAfter;
    _idle = Timer(
      after > Duration.zero ? after : const Duration(minutes: 1),
      () {
        if (!mounted) return;
        ref.read(kioskColumnsRoomProvider.notifier).select(null);
        ref.read(kioskColumnsDeviceProvider.notifier).select(null);
        // Whoever was at the panel has left: everyone's view again.
        ref.read(kioskUserProvider.notifier).select(null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rooms = ref.watch(roomsProvider);
    final chosen = ref.watch(kioskColumnsRoomProvider);
    // `null` = the home overview.
    final unassigned = ref.watch(
      deviceIdsByRoomProvider.select((m) => (m[null] ?? const []).isNotEmpty),
    );
    final roomId =
        (chosen == kioskNoRoom && unassigned) ||
            rooms.any((r) => r.id == chosen)
        ? chosen
        : null;
    // Narrow: a chosen device opens in a sheet instead of the right column.
    ref
      ..listen(kioskColumnsDeviceProvider, (_, id) {
        if (id != null && !_wide && mounted) _openDetail(roomId);
      })
      ..listen(kioskColumnsRoomProvider, (_, _) {
        _scaffold.currentState?.closeDrawer();
      });
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touched(),
      child: LayoutBuilder(
        builder: (context, c) {
          // Three columns need a landscape tablet; portrait drops the right
          // one, and a phone-sized screen keeps the rooms in a drawer.
          _wide = c.maxWidth >= 1100 && c.maxWidth > c.maxHeight;
          final compact = c.maxWidth < 720;
          final middle = Material(
            color: scheme.surfaceContainerLowest,
            // Swipe left/right: next/previous room (Home first).
            child: GestureDetector(
              key: const Key('kioskColumnsSwipe'),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (e) {
                final v = e.primaryVelocity ?? 0;
                if (v.abs() < 300) return;
                _step(
                  [
                    null,
                    for (final r in rooms) r.id,
                    if (unassigned) kioskNoRoom,
                  ],
                  roomId,
                  v < 0 ? 1 : -1,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StaleDataBanner(),
                  const ConnectionProblemCard(),
                  const CriticalAlertsBanner(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      // Fade-through: the old room is gone before the new
                      // one comes, so the two never show at once.
                      switchInCurve: const Interval(
                        0.45,
                        1,
                        curve: Curves.easeOut,
                      ),
                      switchOutCurve: const Interval(
                        0.45,
                        1,
                        curve: Curves.easeIn,
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(0.06 * _direction, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(roomId ?? 'home'),
                        child: roomId == null
                            ? _HomeOverview(withQuickControls: !_wide)
                            : _RoomColumn(roomId: roomId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          return Scaffold(
            key: _scaffold,
            backgroundColor: scheme.surfaceContainerLow,
            drawer: compact
                ? Drawer(
                    backgroundColor: scheme.surfaceContainerLow,
                    child: _Sidebar(roomId: roomId),
                  )
                : null,
            body: Material(
              key: const Key('kioskColumns'),
              color: scheme.surfaceContainerLow,
              child: SafeArea(
                child: compact
                    ? Stack(
                        children: [
                          Positioned.fill(child: middle),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filledTonal(
                              key: const Key('kioskColumnsMenu'),
                              tooltip: context.l10n.navRooms,
                              icon: const Icon(Icons.menu),
                              onPressed: () =>
                                  _scaffold.currentState?.openDrawer(),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _wide ? 300 : 260,
                            child: _Sidebar(roomId: roomId),
                          ),
                          Expanded(child: middle),
                          if (_wide) ...[
                            VerticalDivider(
                              width: 1,
                              color: scheme.outlineVariant,
                            ),
                            SizedBox(
                              width: 380,
                              // Another device slides in from the right.
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: const Interval(
                                  0.45,
                                  1,
                                  curve: Curves.easeOut,
                                ),
                                switchOutCurve: const Interval(
                                  0.45,
                                  1,
                                  curve: Curves.easeIn,
                                ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position:
                                            Tween(
                                              begin: const Offset(0.08, 0),
                                              end: Offset.zero,
                                            ).animate(
                                              CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              ),
                                            ),
                                        child: child,
                                      ),
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    '${roomId ?? 'home'}|'
                                    '${ref.watch(kioskColumnsDeviceProvider)}',
                                  ),
                                  child: _DetailColumn(roomId: roomId),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  final _scaffold = GlobalKey<ScaffoldState>();

  /// Whether the right column is shown (set on layout).
  bool _wide = true;

  bool _sheetOpen = false;

  /// The chosen device's details in a sheet (no right column).
  Future<void> _openDetail(String? roomId) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _DetailColumn(roomId: roomId),
      ),
    );
    _sheetOpen = false;
    if (mounted) ref.read(kioskColumnsDeviceProvider.notifier).select(null);
  }
}

/// No room chosen: the day at a glance.
class _HomeOverview extends ConsumerWidget {
  const _HomeOverview({this.withQuickControls = false});

  /// No right column (portrait): the quick controls come last here.
  final bool withQuickControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Refreshed every half minute: the greeting turns with the day.
    final now = ref.watch(kioskNowProvider);
    final dayGreeting = switch (now.hour) {
      >= 5 && < 12 => l10n.greetingMorning,
      >= 12 && < 18 => l10n.greetingAfternoon,
      >= 18 && < 23 => l10n.greetingEvening,
      _ => l10n.greetingNight,
    };
    final user = ref.watch(kioskUserProvider);
    final userName = user == null
        ? null
        : ref.watch(deviceProvider(user).select((d) => d?.name));
    final greeting = userName == null
        ? dayGreeting
        : l10n.kioskGreetingName(dayGreeting, firstName(userName));
    final hasLists = ref.watch(todoListsProvider).isNotEmpty;
    final cards = ref.watch(kioskSettingsProvider.select((s) => s.homeCards));
    return Stack(
      children: [
        // The sky outside, faintly, behind the greeting.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(child: WeatherSky()),
        ),
        ListView(
          key: const Key('kioskColumnsOverview'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          children: [
            const _BirthdayBanner(),
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      greeting,
                      key: ValueKey(greeting),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('kioskHomeCardsEdit'),
                  tooltip: l10n.kioskHomeCards,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _HomeCardsDialog(),
                  ),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ref.watch(homeSentenceProvider(l10n)),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
            const OnNowStrip(padding: EdgeInsets.only(top: 12)),
            const AirAdviceCard(padding: EdgeInsets.only(top: 12)),
            const SizedBox(height: 4),
            // The household's choice and order of cards (Edit, top right).
            for (final card in cards)
              if (switch (card) {
                HomeCard.cameras =>
                  ref.watch(
                        kioskSettingsProvider.select((s) => s.showCameras),
                      ) &&
                      ref.watch(cameraIdsProvider).isNotEmpty,
                HomeCard.lists => hasLists,
                HomeCard.floorPlan => ref.watch(hasFloorPlanProvider),
                _ => true,
              }) ...[
                const SizedBox(height: 16),
                switch (card) {
                  HomeCard.cameras => const _OverviewCameras(),
                  HomeCard.weather => const WeatherSection(
                    allowDeviceLocation: false,
                  ),
                  HomeCard.media => const NowPlayingCard(),
                  HomeCard.calendar => const _OverviewCalendar(),
                  HomeCard.lists => const TodoListsCard(),
                  HomeCard.floorPlan => const FloorPlanCard(),
                },
              ],
            if (withQuickControls) ...[
              const SizedBox(height: 24),
              const KioskQuickControls(),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Left: home, search (Assist), scenes, rooms, automations, people
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        ref.watch(homeSnapshotProvider.select((s) => s.locationName)) ??
        ref.watch(serverConfigProvider).value?.locationName ??
        Brand.name(l10n);
    final rooms = ref.watch(roomsProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final scenes = ref
        .watch(dashboardSummaryProvider.select((s) => s.sceneIds))
        .map((id) => devices[id])
        .whereType<SmartHomeDevice>()
        .take(8)
        .toList();
    final automations =
        devices.values
            .where((d) => d.kind == DeviceKind.automation && !d.isAuxiliary)
            .toList()
          ..sort(
            (a, b) => (b.state.lastTriggered ?? DateTime(0)).compareTo(
              a.state.lastTriggered ?? DateTime(0),
            ),
          );
    final alarm = ref.watch(kioskAlarmProvider);
    final messages = ref.watch(familyMessagesProvider.select((m) => m.length));

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );

    return ListView(
      key: const Key('kioskColumnsLeft'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps to a second line in a narrow sidebar (portrait).
            Expanded(
              child: Wrap(
                children: [
                  _SideIcon(
                    key: const Key('kioskTimer'),
                    icon: Icons.timer_outlined,
                    tooltip: l10n.timerTitle,
                    onTap: () => showTimerPicker(context, ref),
                  ),
                  if (alarm != null)
                    _SideIcon(
                      key: const Key('kioskAlarm'),
                      icon:
                          alarm.state.alarmState == AlarmState.disarmed ||
                              alarm.state.alarmState == null
                          ? Icons.shield_outlined
                          : Icons.shield,
                      tooltip: DevicePresentation.status(l10n, alarm),
                      onTap: () => showKioskAlarm(context),
                    ),
                  _SideIcon(
                    key: const Key('kioskLeaving'),
                    icon: Icons.directions_walk,
                    tooltip: l10n.kioskLeaving,
                    onTap: () => showKioskLeaving(context),
                  ),
                  _SideIcon(
                    key: const Key('kioskExtras'),
                    icon: Icons.apps,
                    tooltip: l10n.extrasTitle,
                    onTap: () => showExtras(context),
                  ),
                  _SideIcon(
                    key: const Key('kioskMessages'),
                    icon: Icons.forum_outlined,
                    tooltip: l10n.familyMessages,
                    badge: messages,
                    onTap: () => showFamilyMessages(context),
                  ),
                ],
              ),
            ),
            _SideIcon(
              key: const Key('kioskExit'),
              icon: Icons.lock_outline,
              tooltip: l10n.kioskExit,
              onTap: () async {
                if (await showKioskExitDialog(context, ref) &&
                    context.mounted) {
                  context.go(AppRoutes.home);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Who is at the panel: their greeting and quick controls; tapping
        // again (or a while untouched) goes back to everyone.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in ref.watch(peopleIdsProvider).take(6))
              _PersonButton(personId: id),
          ],
        ),
        const SizedBox(height: 12),
        // Search = ask Assist (by text or by voice).
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('kioskAssist'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => showAssist(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Icon(Icons.search, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.assistHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('kioskAssistMic'),
                    tooltip: l10n.assistMic,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showAssist(context, listen: true),
                    icon: Icon(Icons.mic_none, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (scenes.isNotEmpty) ...[
          label(l10n.scenesTitle),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [for (final s in scenes) _SceneCircle(scene: s)],
            ),
          ),
        ],
        label(l10n.navRooms),
        _HomeRow(selected: roomId == null),
        for (final r in rooms)
          _RoomRow(
            key: ValueKey('kioskColumnsRoom-${r.id}'),
            roomId: r.id,
            name: r.name,
            icon: r.icon,
            selected: r.id == roomId,
          ),
        // Devices Home Assistant has in no area: still reachable.
        if ((ref.watch(deviceIdsByRoomProvider)[null] ?? const []).isNotEmpty)
          _RoomRow(
            key: const ValueKey('kioskColumnsRoom-none'),
            roomId: kioskNoRoom,
            name: l10n.roomNoRoom,
            icon: null,
            selected: roomId == kioskNoRoom,
          ),
        if (automations.isNotEmpty) ...[
          label(l10n.automationsTitle),
          for (final a in automations.take(5)) _AutomationRow(device: a),
        ],
      ],
    );
  }
}

/// "Happy birthday, Ana!" on the day (birthdays are set per member).
class _BirthdayBanner extends ConsumerWidget {
  const _BirthdayBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(birthdaysTodayProvider);
    if (ids.isEmpty) return const SizedBox.shrink();
    final names = [for (final id in ids) ?ref.watch(deviceProvider(id))?.name]
        .map(firstName)
        .join(', ');
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const Key('kioskBirthday'),
        elevation: 0,
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  context.l10n.birthdayGreeting(names),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonButton extends ConsumerWidget {
  const _PersonButton({required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chosen = ref.watch(kioskUserProvider) == personId;
    final name = ref.watch(deviceProvider(personId).select((d) => d?.name));
    return Semantics(
      button: true,
      selected: chosen,
      label: name == null ? null : context.l10n.kioskPersonButton(name),
      child: InkWell(
        key: ValueKey('kioskPerson-$personId'),
        customBorder: const CircleBorder(),
        onTap: () => ref.read(kioskUserProvider.notifier).toggle(personId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: chosen ? scheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: PersonAvatar(personId: personId, size: 44),
        ),
      ),
    );
  }
}

/// "Ana Petrović" → "Ana".
String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

class _SideIcon extends StatelessWidget {
  const _SideIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      // Six fit in a row in the left column.
      visualDensity: VisualDensity.compact,
      icon: badge > 0
          ? Badge.count(
              count: badge,
              child: Icon(icon, color: color),
            )
          : Icon(icon, color: color),
    );
  }
}

class _SceneCircle extends ConsumerWidget {
  const _SceneCircle({required this.scene});

  final SmartHomeDevice scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Material(
            key: ValueKey('kioskColumnsScene-${scene.id}'),
            color: scheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () =>
                  runDeviceCommand(context, ref, scene, const Activate()),
              // The scene's own colours, when Home Assistant has them.
              child: SceneSwatch(
                sceneId: scene.id,
                icon: DevicePresentation.icon(scene),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scene.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Agenda on the left, the month on the right, half each.
class _OverviewCalendar extends StatelessWidget {
  const _OverviewCalendar();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const Key('kioskColumnsCalendar'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 330,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: CalendarBrowser(
            palette: CalendarPalette.of(theme),
            evenSplit: true,
            fitGrid: true,
            gridScale: 1.1,
            header: Text(
              l10n.calendarTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which cards the home overview shows, and in what order (drag).
class _HomeCardsDialog extends ConsumerStatefulWidget {
  const _HomeCardsDialog();

  @override
  ConsumerState<_HomeCardsDialog> createState() => _HomeCardsDialogState();
}

class _HomeCardsDialogState extends ConsumerState<_HomeCardsDialog> {
  late final List<HomeCard> _order = [
    ...ref.read(kioskSettingsProvider).homeCards,
    for (final c in HomeCard.values)
      if (!ref.read(kioskSettingsProvider).homeCards.contains(c)) c,
  ];
  late final Set<HomeCard> _shown = {
    ...ref.read(kioskSettingsProvider).homeCards,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(HomeCard c) => switch (c) {
      HomeCard.cameras => l10n.camerasTitle,
      HomeCard.weather => l10n.dashCardWeather,
      HomeCard.media => l10n.mediaTitle,
      HomeCard.calendar => l10n.calendarTitle,
      HomeCard.lists => l10n.todoTitle,
      HomeCard.floorPlan => l10n.floorPlanTitle,
    };
    IconData icon(HomeCard c) => switch (c) {
      HomeCard.cameras => Icons.videocam_outlined,
      HomeCard.weather => Icons.wb_cloudy_outlined,
      HomeCard.media => Icons.music_note_outlined,
      HomeCard.calendar => Icons.calendar_month_outlined,
      HomeCard.lists => Icons.checklist,
      HomeCard.floorPlan => Icons.map_outlined,
    };
    return AlertDialog(
      title: Text(l10n.kioskHomeCards),
      content: SizedBox(
        width: 420,
        height: 380,
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => setState(() {
            _order.insert(to, _order.removeAt(from));
          }),
          children: [
            for (final (i, c) in _order.indexed)
              CheckboxListTile(
                key: ValueKey('kioskHomeCard-${c.name}'),
                value: _shown.contains(c),
                onChanged: (v) => setState(
                  () => v == true ? _shown.add(c) : _shown.remove(c),
                ),
                secondary: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Row(
                  children: [
                    Icon(icon(c), size: 20),
                    const SizedBox(width: 10),
                    Text(label(c)),
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
        FilledButton(
          key: const Key('kioskHomeCardsSave'),
          onPressed: () {
            final navigator = Navigator.of(context);
            ref
                .read(kioskSettingsProvider.notifier)
                .update(
                  (s) => s.copyWith(
                    homeCards: [
                      for (final c in _order)
                        if (_shown.contains(c)) c,
                    ],
                  ),
                );
            navigator.pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// The home's cameras on the overview: one picture, chips to switch.
class _OverviewCameras extends ConsumerStatefulWidget {
  const _OverviewCameras();

  @override
  ConsumerState<_OverviewCameras> createState() => _OverviewCamerasState();
}

class _OverviewCamerasState extends ConsumerState<_OverviewCameras> {
  String? _chosen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ids = ref.watch(cameraIdsProvider);
    final id = ids.contains(_chosen) ? _chosen! : ids.first;
    final camera = ref.watch(deviceProvider(id));
    return Card(
      key: const Key('kioskColumnsCameras'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.camerasTitle, style: theme.textTheme.titleMedium),
            if (ids.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ids)
                    ChoiceChip(
                      key: ValueKey('kioskColumnsCamera-$c'),
                      label: Text(ref.watch(deviceProvider(c))?.name ?? c),
                      selected: c == id,
                      onSelected: (_) => setState(() => _chosen = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (camera != null) _CameraCard(camera: camera),
          ],
        ),
      ),
    );
  }
}

/// "Home": back to the overview.
class _HomeRow extends ConsumerWidget {
  const _HomeRow({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        key: const Key('kioskColumnsHome'),
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ref.read(kioskColumnsRoomProvider.notifier).select(null);
            ref.read(kioskColumnsDeviceProvider.notifier).select(null);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  color: selected ? fg : scheme.primary,
                ),
                const SizedBox(width: 14),
                Text(
                  l10n.navHome,
                  style: theme.textTheme.titleMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomRow extends ConsumerWidget {
  const _RoomRow({
    super.key,
    required this.roomId,
    required this.name,
    required this.icon,
    required this.selected,
  });

  final String roomId;
  final String name;
  final String? icon;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(roomSummaryProvider(_areaOf(roomId)));
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final look = roomLookOf(ref, _areaOf(roomId), icon, name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ref.read(kioskColumnsRoomProvider.notifier).select(roomId);
            ref.read(kioskColumnsDeviceProvider.notifier).select(null);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(look.icon, color: selected ? fg : look.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                ),
                if (summary.lightsOn > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.lightbulb,
                      size: 18,
                      color: selected ? fg : const Color(0xFFFFB300),
                    ),
                  ),
                if (summary.alertCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: selected ? fg : context.statusColors.critical,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutomationRow extends StatelessWidget {
  const _AutomationRow({required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final last = device.state.lastTriggered;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
      leading: Icon(
        Icons.schedule,
        color: device.state.isOn == true
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          device.state.isOn == true ? l10n.stateOn : l10n.stateOff,
          if (last != null)
            DevicePresentation.relativeTime(l10n, last, DateTime.now()),
        ].join(' · '),
      ),
      onTap: () => context.push(AppRoutes.device(device.id, kiosk: true)),
    );
  }
}

// ---------------------------------------------------------------------------
// Middle: the room
// ---------------------------------------------------------------------------

class _RoomColumn extends ConsumerWidget {
  const _RoomColumn({required this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (roomId == null) {
      return Center(child: Text(l10n.kioskColumnsNoRooms));
    }
    final room = ref
        .watch(roomsProvider)
        .where((r) => r.id == roomId)
        .firstOrNull;
    final area = _areaOf(roomId!);
    final summary = ref.watch(roomSummaryProvider(area));
    final ids = ref.watch(deviceIdsByRoomProvider)[area] ?? const <String>[];
    final devices = [for (final id in ids) ?ref.watch(deviceProvider(id))]
        .where((d) => !d.isAuxiliary && !d.kind.isRoutine)
        .toList();
    final media = devices
        .where(
          (d) =>
              d.kind == DeviceKind.mediaPlayer || d.kind == DeviceKind.speaker,
        )
        .firstOrNull;
    final cameras = devices.where((d) => d.kind == DeviceKind.camera).toList();
    // One card per physical device (its buttons, modes and sensors
    // together), not one per entity.
    final accessories = groupDevices([
      for (final d in devices)
        if (d.id != media?.id && d.kind != DeviceKind.camera) d,
    ]);
    final selected = ref.watch(kioskColumnsDeviceProvider);
    String n(double v, String unit) =>
        formatNumber(l10n.localeName, v, unit: unit);

    return ListView(
      key: ValueKey('kioskColumnsRoomView-$roomId'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        // The room's own photo (chosen on this tablet), when it has one.
        if (roomId case final id? when _areaOf(id) != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RoomPhotoHeader(roomId: id, height: 200),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                roomId == kioskNoRoom ? l10n.roomNoRoom : room?.name ?? '',
                key: const Key('kioskColumnsRoomTitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (summary.humidity != null) ...[
              Icon(
                Icons.water_drop_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              CountUpText(
                value: summary.humidity!,
                format: (v) => n(v, '%'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 14),
            ],
            if (summary.temperature != null) ...[
              Icon(Icons.thermostat, size: 18, color: scheme.onSurfaceVariant),
              CountUpText(
                value: summary.temperature!,
                format: (v) => n(v, '°'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.kioskColumnsDevices, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final columns = math.max(2, (c.maxWidth / 170).floor());
            final width = (c.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, g) in accessories.indexed)
                  SizedBox(
                    width: width,
                    height: 136,
                    // The room's cards arrive as a wave.
                    child: StaggeredEntrance(
                      index: i,
                      child: _AccessoryCard(
                        group: g,
                        selected:
                            g.key == selected ||
                            g.members.any((m) => m.id == selected),
                        roomName: room?.name,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (media != null) ...[
          const SizedBox(height: 16),
          SizedBox(height: 230, child: KioskMediaPanel(playerId: media.id)),
        ],
        if (cameras.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.camerasTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final c in cameras) ...[
            _CameraCard(camera: c),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

/// A device in the room: tap shows it on the right, tapping its icon does
/// the quick action (switch on/off), long press opens its full screen.
class _AccessoryCard extends ConsumerWidget {
  const _AccessoryCard({
    required this.group,
    required this.selected,
    this.roomName,
  });

  /// One entity, or all of one physical device (shown by its main entity).
  final DeviceBundle group;
  final bool selected;

  /// Left out of the name ("Living room – lamp" → "Lamp").
  final String? roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = group.primary;
    final tone = DevicePresentation.tone(d);
    final on = tone == DeviceTone.active;
    final accent = DevicePresentation.swatch(context.deviceAccents, d);
    final iconBg = !d.available
        ? scheme.surfaceContainerHighest
        : on
        ? accent.icon
        : scheme.surfaceContainerHighest;
    final iconFg = on && d.available ? Colors.white : scheme.onSurfaceVariant;
    final quick = DevicePresentation.hasQuickToggle(d) && d.available;
    final status = !group.available
        ? l10n.stateUnavailable
        : DevicePresentation.status(l10n, d);
    // A light turning on glows once in its colour.
    return OnGlow(
      on: on && d.kind.isLight,
      color: accent.icon,
      radius: 22,
      child: Material(
        key: ValueKey('kioskColumnsDevice-${group.key}'),
        color: scheme.surface,
        elevation: selected ? 3 : 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              ref.read(kioskColumnsDeviceProvider.notifier).select(group.key),
          // A level to slide: the big slider; else the device's screen.
          onLongPress: () => bigSliderFor(context.l10n, d) != null
              ? showBigSlider(context, d.id)
              : context.push(AppRoutes.device(d.id, kiosk: true)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Material(
                      color: iconBg,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: ValueKey('kioskColumnsToggle-${d.id}'),
                        customBorder: const CircleBorder(),
                        onTap: quick
                            ? () => runDeviceCommand(
                                context,
                                ref,
                                d,
                                d.state.isOn == true
                                    ? const TurnOff()
                                    : const TurnOn(),
                              )
                            : () => ref
                                  .read(kioskColumnsDeviceProvider.notifier)
                                  .select(group.key),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: LiveDeviceIcon(device: d, color: iconFg),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (d.state.raw == 'playing' && d.available)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: EqualizerBars(color: accent.icon),
                      ),
                    if (group.isGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${group.members.length}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    if (tone == DeviceTone.warning ||
                        tone == DeviceTone.critical)
                      Icon(
                        Icons.error_outline,
                        color: tone == DeviceTone.critical
                            ? context.statusColors.critical
                            : context.statusColors.warning,
                      ),
                  ],
                ),
                // Name and state at the bottom; a long name gives up its
                // second line rather than overflow the card.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          DevicePresentation.shortName(group.name, roomName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final SmartHomeDevice camera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: CameraPicture(cameraId: camera.id, fit: BoxFit.cover),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    camera.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () =>
                      context.push(AppRoutes.device(camera.id, kiosk: true)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right: the chosen device, this week's energy
// ---------------------------------------------------------------------------

class _DetailColumn extends ConsumerWidget {
  const _DetailColumn({required this.roomId});

  final String? roomId;

  /// The room's climate device, else a light, else any device.
  static String? _fallback(List<SmartHomeDevice> devices) {
    for (final pick in [
      (SmartHomeDevice d) =>
          d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat,
      (SmartHomeDevice d) => d.kind.isLight,
      (SmartHomeDevice d) => d.kind != DeviceKind.camera,
    ]) {
      final d = devices.where(pick).firstOrNull;
      if (d != null) return d.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // On the home overview: the home's thermostat.
    final thermostat = ref.watch(kioskThermostatIdProvider);
    final ids = roomId == null
        ? [?thermostat]
        : ref.watch(deviceIdsByRoomProvider)[_areaOf(roomId!)] ??
              const <String>[];
    final devices = [for (final id in ids) ?ref.watch(deviceProvider(id))]
        .where((d) => !d.isAuxiliary && !d.kind.isRoutine)
        .toList();
    final chosen = ref.watch(kioskColumnsDeviceProvider);
    // A whole physical device chosen in the middle.
    if (chosen != null && chosen.startsWith('group:')) {
      final bundle = groupDevices(devices)
          .where((b) => b.key == chosen)
          .firstOrNull;
      if (bundle != null) {
        return ListView(
          key: const Key('kioskColumnsDetail'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            KioskBundleDetail(bundle: bundle),
            const SizedBox(height: 20),
            const _WeekEnergyCard(),
          ],
        );
      }
    }
    final id = devices.any((d) => d.id == chosen) ? chosen : _fallback(devices);
    final d = id == null ? null : ref.watch(deviceProvider(id));
    final climate =
        d != null &&
        (d.kind == DeviceKind.climate || d.kind == DeviceKind.thermostat);

    return ListView(
      key: const Key('kioskColumnsDetail'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // Home overview: the devices chosen to keep at hand come first.
        if (roomId == null) ...[
          const KioskQuickControls(),
          const SizedBox(height: 24),
        ],
        if (d != null) ...[
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.deviceAccents
                    .of(DevicePresentation.accent(d))
                    .icon,
                child: Icon(DevicePresentation.icon(d), color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      key: const Key('kioskColumnsDetailName'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DevicePresentation.status(l10n, d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.kioskOpenDevice,
                onPressed: () =>
                    context.push(AppRoutes.device(d.id, kiosk: true)),
                icon: const Icon(Icons.open_in_full),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (climate)
            SizedBox(height: 440, child: KioskThermostatPanel(deviceId: d.id))
          else
            ...deviceControlsFor(d),
          // A sensor's last day (or week) as a chart.
          if (d.kind.isSensor || d.state.numericValue != null) ...[
            const SizedBox(height: 16),
            DeviceHistorySection(
              key: ValueKey('kioskColumnsHistory-${d.id}'),
              device: d,
            ),
          ],
          const SizedBox(height: 20),
        ],
        const _WeekEnergyCard(),
      ],
    );
  }
}

class _WeekEnergyCard extends ConsumerWidget {
  const _WeekEnergyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final report = ref.watch(_weekEnergyProvider).value;
    if (report == null || report.buckets.isEmpty) {
      return const SizedBox.shrink();
    }
    final values = [for (final b in report.buckets) b.consumption ?? 0];
    final top = values.fold<double>(0, math.max);
    final today = DateUtils.dateOnly(DateTime.now());
    return Card(
      key: const Key('kioskColumnsWeek'),
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.energyWeek,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, b) in report.buckets.indexed)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: top <= 0
                                    ? 0.02
                                    : math.max(0.02, values[i] / top),
                                child: Container(
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: DateUtils.isSameDay(b.start, today)
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.E(l10n.localeName)
                                .format(b.start)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: DateUtils.isSameDay(b.start, today)
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (report.consumption != null)
              CountUpText(
                value: report.consumption!,
                format: (v) => formatKwh(l10n.localeName, v),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
