import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/responsive.dart';
import '../localization/l10n.dart';
import 'app_router.dart';
import '../../features/search/command_palette.dart';

/// Adaptive navigation: bottom [NavigationBar] on phones, [NavigationRail]
/// on tablets and larger screens (extended with labels on large screens).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final index = AppRoutes.shellIndexFor(location);
    void onSelect(int i) => context.go(AppRoutes.shellDestinations[i]);

    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.navHome),
      (Icons.meeting_room_outlined, Icons.meeting_room, l10n.navRooms),
      (Icons.star_border, Icons.star, l10n.navFavorites),
      (Icons.palette_outlined, Icons.palette, l10n.navScenes),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = WindowSize.fromWidth(constraints.maxWidth);
        if (!size.usesNavigationRail) {
          return Scaffold(
            body: child,
            // Labels grow with the font size only so far that they still
            // fit; the icons and tooltips carry the rest.
            bottomNavigationBar: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final (icon, selected, label) in destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
            ),
          );
        }
        final extended = size == WindowSize.large;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: onSelect,
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  // Find anything (also Ctrl+K).
                  leading: IconButton(
                    key: const Key('railSearch'),
                    tooltip: l10n.paletteTooltip,
                    onPressed: () => showCommandPalette(context),
                    icon: const Icon(Icons.search),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
