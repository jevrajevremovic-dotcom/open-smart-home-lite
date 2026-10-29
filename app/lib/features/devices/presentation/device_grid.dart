import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/value_list.dart';
import '../../../core/widgets/responsive.dart';
import '../application/device_groups.dart';
import '../application/device_providers.dart';
import '../domain/smart_home_device.dart';
import 'device_tile.dart';

/// One card of a grouped grid: a device on its own, or a physical device
/// ([group] id) standing for its [count] parts through [id], its main one.
typedef _Item = ({String id, String? group, String? name, int count});

ValueList<_Item> _groupItems(
  Map<String, SmartHomeDevice> devices,
  List<String> ids,
  List<String> all,
) {
  final bundles = groupDevices([for (final id in all) ?devices[id]]);
  final byPrimary = {for (final b in bundles) b.primary.id: b};
  final parts = {
    for (final b in bundles)
      if (b.isGroup)
        for (final m in b.members) m.id,
  };
  return ValueList([
    for (final id in ids)
      if (byPrimary[id] case final b? when b.isGroup)
        (
          id: id,
          group: b.members.first.deviceId,
          name: b.name,
          count: b.members.length,
        )
      else if (!parts.contains(id))
        (id: id, group: null, name: null, count: 1),
  ]);
}

/// Of [all], the parts that a grouped grid shows inside their physical
/// device's card instead of on their own (all but each group's main one).
ValueList<String> groupedParts(
  Map<String, SmartHomeDevice> devices,
  List<String> all,
) => ValueList([
  for (final b in groupDevices([for (final id in all) ?devices[id]]))
    if (b.isGroup)
      for (final m in b.members)
        if (m.id != b.primary.id) m.id,
]);

/// Lazily built, responsive grid of [DeviceTile]s.
///
/// Tile width adapts to the screen (wider on tablets and wall panels); tile
/// height grows with the user's text scale so labels never get clipped.
class DeviceSliverGrid extends ConsumerWidget {
  const DeviceSliverGrid({
    super.key,
    required this.deviceIds,
    this.withoutRoomName = false,
    this.groupFrom,
  });

  final List<String> deviceIds;

  /// See [DeviceTile.withoutRoomName].
  final bool withoutRoomName;

  /// One card per physical device (an air fryer, not its twenty parts),
  /// grouped among these ids (e.g. the whole room's, when [deviceIds] is
  /// one of its sections).
  final List<String>? groupFrom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = groupFrom;
    final items = all == null
        ? null
        : ref.watch(
            homeSnapshotProvider.select(
              (s) => _groupItems(s.devices, deviceIds, all),
            ),
          );
    final size = WindowSize.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: switch (size) {
          WindowSize.compact => 200,
          WindowSize.medium => 220,
          _ => 240,
        },
        mainAxisExtent: 148 * textScale,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items?.length ?? deviceIds.length,
      itemBuilder: (context, i) {
        final item = items?[i];
        if (item == null || item.group == null) {
          final id = item?.id ?? deviceIds[i];
          return DeviceTile(
            key: ValueKey(id),
            deviceId: id,
            withoutRoomName: withoutRoomName,
          );
        }
        return DeviceTile(
          key: ValueKey('group:${item.group}'),
          deviceId: item.id,
          withoutRoomName: withoutRoomName,
          group: (id: item.group!, name: item.name!, count: item.count),
        );
      },
    );
  }
}

/// Section title used on dashboard, rooms and favorites screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Centered hint for empty sections: the icon in soft rings (a small
/// illustration rather than a grey glyph), the text, and an optional way
/// forward.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withValues(alpha: 0.35),
              ),
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
