import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../dashboard/application/home_summaries.dart';
import '../../devices/application/device_command_service.dart'
    show isGroupCover;
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/all_lights.dart';
import '../../restricted/application/restricted_mode.dart';
import '../../devices/presentation/device_grid.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../devices/presentation/stale_data_banner.dart';
import 'room_card.dart';
import 'room_photo.dart';

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rooms = ref.watch(roomsProvider);
    final hasUnassigned = ref.watch(
      deviceIdsByRoomProvider.select((m) => m.containsKey(null)),
    );

    final entries = [
      for (final r in rooms) (r.id, r.name, r.icon),
      if (hasUnassigned) (null, l10n.roomNoRoom, null),
    ];

    // With floors set up in HA: one section per floor, lowest first.
    final floors = <String, int?>{
      for (final r in rooms)
        if (r.floorName != null) r.floorName!: r.floorLevel,
    };
    final floorOrder = floors.keys.toList()
      ..sort((a, b) {
        final la = floors[a] ?? 1 << 20;
        final lb = floors[b] ?? 1 << 20;
        return la != lb ? la.compareTo(lb) : a.compareTo(b);
      });
    final sections = <(String?, List<(String?, String, String?)>)>[
      for (final f in floorOrder)
        (
          f,
          [
            for (final r in rooms)
              if (r.floorName == f) (r.id, r.name, r.icon),
          ],
        ),
      (
        floorOrder.isEmpty ? null : l10n.floorOther,
        [
          for (final r in rooms)
            if (r.floorName == null) (r.id, r.name, r.icon),
          if (hasUnassigned) (null, l10n.roomNoRoom, null),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navRooms),
        actions: [
          if (!ref.watch(restrictedModeProvider).enabled)
            IconButton(
              key: const Key('openAddDevice'),
              tooltip: l10n.addDeviceTitle,
              onPressed: () => context.push(AppRoutes.addDevice),
              icon: const Icon(Icons.add),
            ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.allDevices),
            icon: const Icon(Icons.list),
            label: Text(l10n.allDevices),
          ),
        ],
      ),
      body: MockModeBanner(
        child: CustomScrollView(
          slivers: [
            if (entries.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: EmptyHint(
                    icon: Icons.meeting_room_outlined,
                    text: l10n.noRoomsYet,
                  ),
                ),
              )
            else
              for (final (title, list) in sections)
                if (list.isNotEmpty) ...[
                  if (title != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: SectionHeader(
                          title,
                          key: ValueKey('floor-$title'),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: RoomSliverGrid(rooms: list),
                  ),
                ],
          ],
        ),
      ),
    );
  }
}

/// Devices of one room, grouped by category. `roomId == null` shows
/// devices without a room.
class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = roomId == null
        ? l10n.roomNoRoom
        : ref.watch(
                homeSnapshotProvider.select((s) => s.rooms[roomId]?.name),
              ) ??
              '';
    final sections = ref.watch(roomDeviceGroupsProvider(roomId));
    // One card per physical device: its parts are left out of the sections
    // (the card sits in its main part's section).
    final all = [for (final (_, ids) in sections) ...ids];
    final parts = ref
        .watch(homeSnapshotProvider.select((s) => groupedParts(s.devices, all)))
        .toSet();
    final groups = [
      for (final (group, ids) in sections)
        if (ids.where((id) => !parts.contains(id)).toList() case final shown
            when shown.isNotEmpty)
          (group, shown),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [if (roomId case final id?) RoomPhotoButton(roomId: id)],
      ),
      body: CustomScrollView(
        slivers: [
          if (roomId case final id?)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(child: RoomPhotoHeader(roomId: id)),
            ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: StaleDataBanner()),
          ),
          if (groups.isEmpty)
            SliverToBoxAdapter(
              child: EmptyHint(
                icon: Icons.devices_other_outlined,
                text: l10n.roomEmpty,
              ),
            ),
          for (final (group, ids) in groups) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(groupLabel(l10n, group)),
              ),
            ),
            if (group == DeviceGroup.lights && ids.length > 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: AllLightsButtons(roomId: roomId),
                ),
              ),
            if (group == DeviceGroup.covers &&
                ref
                        .watch(homeSnapshotProvider)
                        .devices
                        .values
                        .where((d) => ids.contains(d.id) && isGroupCover(d))
                        .length >
                    1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: AllCoversButtons(roomId: roomId),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: DeviceSliverGrid(
                deviceIds: ids,
                withoutRoomName: true,
                groupFrom: all,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Every device, with a search over names, rooms and types.
class AllDevicesScreen extends ConsumerStatefulWidget {
  const AllDevicesScreen({super.key});

  @override
  ConsumerState<AllDevicesScreen> createState() => _AllDevicesScreenState();
}

class _AllDevicesScreenState extends ConsumerState<AllDevicesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ids = ref.watch(visibleDeviceIdsProvider);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final rooms = ref.watch(homeSnapshotProvider.select((s) => s.rooms));
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final shown = words.isEmpty
        ? ids
        : [
            for (final id in ids)
              if (devices[id] case final d?)
                if (words.every(
                  (w) => [
                    d.name,
                    rooms[d.roomId]?.name ?? '',
                    groupLabel(l10n, groupOf(d.kind)),
                    DevicePresentation.status(l10n, d),
                  ].any((field) => field.toLowerCase().contains(w)),
                ))
                  id,
          ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allDevices)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: TextField(
                key: const Key('deviceSearch'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.deviceSearchHint,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: shown.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyHint(
                      icon: Icons.search_off,
                      text: l10n.deviceSearchEmpty,
                    ),
                  )
                : DeviceSliverGrid(deviceIds: shown),
          ),
        ],
      ),
    );
  }
}

String groupLabel(AppLocalizations l10n, DeviceGroup group) => switch (group) {
  DeviceGroup.lights => l10n.groupLights,
  DeviceGroup.climate => l10n.groupClimate,
  DeviceGroup.covers => l10n.groupCovers,
  DeviceGroup.switches => l10n.groupSwitches,
  DeviceGroup.security => l10n.groupSecurity,
  DeviceGroup.sensors => l10n.groupSensors,
  DeviceGroup.media => l10n.groupMedia,
  DeviceGroup.energy => l10n.groupEnergy,
  DeviceGroup.other => l10n.groupOther,
};
