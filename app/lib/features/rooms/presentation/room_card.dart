import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../dashboard/application/home_summaries.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../kiosk/presentation/glass.dart' show kioskPhotoStoreProvider;
import 'room_look.dart';
import 'room_photo.dart' show roomPhotosProvider;
import 'room_sparkline.dart';

/// Maps common Material Design Icons names used for HA areas to Material
/// icons. Unknown names fall back to a generic room icon.
IconData roomIcon(String? mdi) => switch (mdi) {
  'mdi:sofa' ||
  'mdi:sofa-outline' ||
  'mdi:television' => Icons.weekend_outlined,
  'mdi:bed' ||
  'mdi:bed-outline' ||
  'mdi:bed-king' ||
  'mdi:bed-empty' => Icons.bed_outlined,
  'mdi:door' ||
  'mdi:door-open' ||
  'mdi:door-closed' => Icons.door_front_door_outlined,
  'mdi:countertop' ||
  'mdi:stove' ||
  'mdi:fridge' ||
  'mdi:silverware-fork-knife' => Icons.kitchen_outlined,
  'mdi:garage' || 'mdi:garage-variant' => Icons.garage_outlined,
  'mdi:tree' ||
  'mdi:flower' ||
  'mdi:grass' ||
  'mdi:pine-tree' => Icons.park_outlined,
  'mdi:shower' || 'mdi:bathtub' || 'mdi:toilet' => Icons.bathtub_outlined,
  'mdi:desk' || 'mdi:laptop' || 'mdi:briefcase' => Icons.desk_outlined,
  'mdi:baby-carriage' ||
  'mdi:teddy-bear' ||
  'mdi:human-child' => Icons.child_care_outlined,
  'mdi:stairs' => Icons.stairs_outlined,
  'mdi:washing-machine' => Icons.local_laundry_service_outlined,
  _ => Icons.meeting_room_outlined,
};

/// Each kind of room has its own colour, so rooms read as places (and look
/// different from device tiles, whose colour follows their state).
Color roomColor(String? mdi, String name) {
  final icon = roomIcon(mdi);
  return switch (icon) {
    Icons.weekend_outlined => const Color(0xFFE0A030),
    Icons.bed_outlined => const Color(0xFF6B6FD6),
    Icons.kitchen_outlined => const Color(0xFF3FA37A),
    Icons.bathtub_outlined => const Color(0xFF3A8FD0),
    Icons.garage_outlined => const Color(0xFF7A8794),
    Icons.park_outlined => const Color(0xFF58A048),
    Icons.door_front_door_outlined => const Color(0xFFC9786A),
    Icons.desk_outlined => const Color(0xFF9A6BD0),
    Icons.child_care_outlined => const Color(0xFFE07AA8),
    Icons.stairs_outlined => const Color(0xFFB08A5A),
    Icons.local_laundry_service_outlined => const Color(0xFF4FB3BF),
    _ =>
      _roomPalette[name.codeUnits.fold(0, (a, c) => a + c) %
          _roomPalette.length],
  };
}

const _roomPalette = [
  Color(0xFFE0A030),
  Color(0xFF6B6FD6),
  Color(0xFF3FA37A),
  Color(0xFF3A8FD0),
  Color(0xFFC9786A),
  Color(0xFF9A6BD0),
  Color(0xFF4FB3BF),
];

class RoomCard extends ConsumerWidget {
  const RoomCard({
    super.key,
    required this.roomId,
    required this.name,
    this.icon,
  });

  /// `null` = devices without a room.
  final String? roomId;
  final String name;
  final String? icon;

  static const radius = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final summary = ref.watch(roomSummaryProvider(roomId));
    final look = roomLookOf(ref, roomId, icon, name);
    final color = look.color;
    // The room's own photo fills the card, darkened for white text.
    final photoPath = roomId == null
        ? null
        : ref.watch(roomPhotosProvider.select((m) => m[roomId]));
    final photo = photoPath == null
        ? null
        : ref.watch(kioskPhotoStoreProvider).image(photoPath);
    final base = dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest;
    final top = Color.lerp(base, color, dark ? 0.16 : 0.10)!;
    final bottom = Color.lerp(base, color, dark ? 0.34 : 0.26)!;
    final fg = photo != null ? Colors.white : scheme.onSurface;
    final sub = photo != null
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final lightsOn = summary.lightsOn > 0;
    final amber = context.deviceAccents.of(DeviceAccent.light);

    return Semantics(
      button: true,
      label: [
        name,
        if (summary.temperature != null)
          formatNumber(l10n.localeName, summary.temperature!, unit: '°'),
        if (lightsOn) l10n.roomLightsOn(summary.lightsOn),
        l10n.roomDevicesCount(summary.deviceCount),
        if (summary.alertCount > 0) l10n.summaryAlerts,
      ].join(', '),
      excludeSemantics: true,
      child: DecoratedBox(
        key: photo == null ? null : ValueKey('roomCardPhoto-$roomId'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          image: photo == null
              ? null
              : DecorationImage(
                  image: ResizeImage.resizeIfNeeded(800, null, photo),
                  fit: BoxFit.cover,
                ),
          gradient: photo != null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [top, bottom],
                ),
        ),
        child: DecoratedBox(
          // Over a photo: dark at the top (name) and bottom (pills).
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: photo == null
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x33000000),
                      Color(0x99000000),
                    ],
                  ),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(
                AppRoutes.room(roomId, kiosk: ref.read(kioskActiveProvider)),
              ),
              child: Stack(
                children: [
                  // The room's picture: a large, faint icon in the corner
                  // (a photo, when there is one, takes its place).
                  if (photo == null)
                    Positioned(
                      right: -14,
                      bottom: -18,
                      child: Icon(
                        look.icon,
                        size: 112,
                        color: color.withValues(alpha: dark ? 0.30 : 0.24),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                    // Long names and large text give way (fewer lines, a
                    // smaller temperature) instead of overflowing the card.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (summary.alertCount > 0)
                                Tooltip(
                                  message: l10n.summaryAlerts,
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 20,
                                    color: context.statusColors.warning,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (summary.temperature != null)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    formatNumber(
                                      l10n.localeName,
                                      summary.temperature!,
                                      unit: '°',
                                    ),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: fg,
                                          fontWeight: FontWeight.w300,
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  // The last day: warming or cooling?
                                  RoomSparkline(roomId: roomId, color: fg),
                                ],
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (lightsOn)
                              _Pill(
                                icon: Icons.lightbulb,
                                text: '${summary.lightsOn}',
                                background: amber.container,
                                foreground: amber.onContainer,
                              )
                            else
                              _Pill(
                                icon: Icons.devices_other_outlined,
                                text: '${summary.deviceCount}',
                                background: base.withValues(alpha: 0.7),
                                foreground: sub,
                              ),
                            if (summary.humidity != null)
                              _Pill(
                                icon: Icons.water_drop_outlined,
                                text: formatNumber(
                                  l10n.localeName,
                                  summary.humidity!,
                                  unit: '%',
                                ),
                                background: base.withValues(alpha: 0.7),
                                foreground: sub,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground),
        ),
      ],
    ),
  );
}

/// Responsive grid of room cards (lazy).
class RoomSliverGrid extends ConsumerWidget {
  const RoomSliverGrid({super.key, required this.rooms});

  final List<(String?, String, String?)> rooms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150 * textScale,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, i) {
        final (id, name, icon) = rooms[i];
        return RoomCard(key: ValueKey(id), roomId: id, name: name, icon: icon);
      },
    );
  }
}
