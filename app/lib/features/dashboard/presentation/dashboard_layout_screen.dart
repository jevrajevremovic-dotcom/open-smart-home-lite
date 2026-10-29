import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../application/dashboard_layout.dart';

String dashboardCardLabel(AppLocalizations l10n, DashboardCard c) =>
    switch (c) {
      DashboardCard.summary => l10n.dashCardSummary,
      DashboardCard.weather => l10n.dashCardWeather,
      DashboardCard.media => l10n.dashCardMedia,
      DashboardCard.notifications => l10n.dashCardNotifications,
      DashboardCard.lists => l10n.dashCardLists,
      DashboardCard.shortcuts => l10n.dashCardShortcuts,
      DashboardCard.scenes => l10n.scenesTitle,
      DashboardCard.attention => l10n.dashCardAttention,
      DashboardCard.favorites => l10n.navFavorites,
      DashboardCard.rooms => l10n.navRooms,
    };

IconData _icon(DashboardCard c) => switch (c) {
  DashboardCard.summary => Icons.space_dashboard_outlined,
  DashboardCard.weather => Icons.cloud_outlined,
  DashboardCard.media => Icons.music_note_outlined,
  DashboardCard.notifications => Icons.notifications_none,
  DashboardCard.lists => Icons.checklist,
  DashboardCard.shortcuts => Icons.bolt_outlined,
  DashboardCard.scenes => Icons.palette_outlined,
  DashboardCard.attention => Icons.build_circle_outlined,
  DashboardCard.favorites => Icons.star_border,
  DashboardCard.rooms => Icons.meeting_room_outlined,
};

/// Choose and order the home screen's cards.
class DashboardLayoutScreen extends ConsumerWidget {
  const DashboardLayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = ref.watch(dashboardLayoutProvider);
    final controller = ref.read(dashboardLayoutProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashLayoutTitle),
        actions: [
          if (!layout.isDefault)
            TextButton(
              key: const Key('dashLayoutReset'),
              onPressed: controller.reset,
              child: Text(l10n.dashLayoutReset),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.dashLayoutHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              key: const Key('dashLayoutList'),
              padding: const EdgeInsets.all(8),
              buildDefaultDragHandles: false,
              itemCount: layout.order.length,
              onReorderItem: controller.move,
              itemBuilder: (context, i) {
                final card = layout.order[i];
                final shown = !layout.hidden.contains(card);
                return ListTile(
                  key: ValueKey(card),
                  leading: Icon(_icon(card)),
                  title: Text(dashboardCardLabel(l10n, card)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        key: ValueKey('dashCard-${card.name}'),
                        value: shown,
                        onChanged: (v) => controller.setVisible(card, v),
                      ),
                      // Without dragging (and for screen readers).
                      IconButton(
                        key: ValueKey('dashUp-${card.name}'),
                        tooltip: l10n.dashMoveUp,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: i == 0
                            ? null
                            : () => controller.move(i, i - 1),
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
        ],
      ),
    );
  }
}
