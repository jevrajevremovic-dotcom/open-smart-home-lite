import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

import '../../devices/presentation/device_presentation.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/utils/value_list.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_grid.dart';
import '../../devices/presentation/stale_data_banner.dart';
import '../../restricted/application/restricted_mode.dart';
import '../application/favorites_controller.dart';

/// Favorite ids that still exist on the server, in the user's order.
final existingFavoritesProvider = Provider<ValueList<String>>((ref) {
  final favorites = ref.watch(favoritesProvider);
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final restricted = ref.watch(restrictedModeProvider);
  // Not synced yet: keep the stored order; tiles of missing devices hide.
  if (devices.isEmpty) return ValueList(favorites);
  return ValueList([
    for (final id in favorites)
      if (devices[id] case final d? when !restricted.hides(d)) id,
  ]);
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ids = ref.watch(existingFavoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFavorites),
        actions: [
          if (ids.length > 1)
            IconButton(
              key: const Key('reorderFavorites'),
              tooltip: l10n.favoritesReorder,
              icon: const Icon(Icons.swap_vert),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _ReorderFavoritesScreen(),
                ),
              ),
            ),
        ],
      ),
      body: MockModeBanner(
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: StaleDataBanner()),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: ids.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyHint(
                        icon: Icons.star_border,
                        text: l10n.favoritesEmpty,
                        actionLabel: l10n.favoritesBrowse,
                        onAction: () => context.push(AppRoutes.allDevices),
                      ),
                    )
                  : DeviceSliverGrid(deviceIds: ids),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag to change the order favorites appear in (dashboard, kiosk).
class _ReorderFavoritesScreen extends ConsumerWidget {
  const _ReorderFavoritesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ids = ref.watch(existingFavoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesReorder)),
      body: ReorderableListView.builder(
        key: const Key('favoritesReorderList'),
        padding: const EdgeInsets.all(8),
        itemCount: ids.length,
        onReorderItem: (from, to) {
          final list = [...ids];
          final item = list.removeAt(from);
          list.insert(to, item);
          ref.read(favoritesProvider.notifier).setOrder(list);
        },
        itemBuilder: (context, i) => Consumer(
          key: ValueKey(ids[i]),
          builder: (context, ref, _) {
            final d = ref.watch(deviceProvider(ids[i]));
            return ListTile(
              leading: d == null ? null : Icon(DevicePresentation.icon(d)),
              title: Text(d?.name ?? ids[i]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.removeFavorite,
                    icon: const Icon(Icons.star),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(ids[i]),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
