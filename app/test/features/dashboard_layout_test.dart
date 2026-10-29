import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/dashboard/application/dashboard_layout.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('stored layout is read tolerantly', () {
    final l = DashboardLayout.fromJson({
      'order': ['rooms', 'nonsense', 'weather', 'rooms'],
      'hidden': ['media', 'nonsense'],
    });
    expect(l.order.take(2), [DashboardCard.rooms, DashboardCard.weather]);
    expect(l.order.toSet(), DashboardCard.values.toSet(), reason: 'new cards');
    expect(l.order, hasLength(DashboardCard.values.length));
    expect(l.hidden, {DashboardCard.media});
    expect(const DashboardLayout().isDefault, isTrue);
    expect(DashboardLayout.fromJson(null).isDefault, isTrue);
  });

  testWidgets('hide a card and move favorites to the top', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(400, 1400));
    await settle(tester, 10);
    expect(find.text(en.weatherAtHome), findsOneWidget);

    await goTo(tester, AppRoutes.dashboardLayout);
    await tester.tap(find.byKey(const ValueKey('dashCard-weather')));
    await settle(tester, 2);
    // Favorites from its place to the top.
    final steps = DashboardCard.values.indexOf(DashboardCard.favorites);
    for (var i = 0; i < steps; i++) {
      await tester.tap(find.byKey(const ValueKey('dashUp-favorites')));
      await settle(tester, 1);
    }
    await goTo(tester, AppRoutes.home);
    await settle(tester, 4);

    expect(find.text(en.weatherAtHome), findsNothing);
    final favorites = tester.getTopLeft(find.text(en.navFavorites).first).dy;
    final summary = tester.getTopLeft(find.text(en.summaryLights)).dy;
    expect(favorites, lessThan(summary));

    await goTo(tester, AppRoutes.dashboardLayout);
    await tapKey(tester, 'dashLayoutReset');
    await settle(tester, 2);
    await goTo(tester, AppRoutes.home);
    await settle(tester, 4);
    expect(find.text(en.weatherAtHome), findsOneWidget);
    await unmount(tester);
  });
}
