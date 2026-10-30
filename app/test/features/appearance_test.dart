import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/app/theme/app_theme.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';
import 'package:open_smart_home_lite/features/weather/application/weather_providers.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('every accent keeps readable text on its colours', () {
    for (final a in AppAccent.values) {
      for (final t in [
        AppTheme.light(accent: accentColor(a)),
        AppTheme.dark(accent: accentColor(a)),
      ]) {
        final s = t.colorScheme;
        expect(
          DeviceAccents.contrastRatio(s.onPrimary, s.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$a ${s.brightness}',
        );
        expect(
          DeviceAccents.contrastRatio(s.onPrimaryContainer, s.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$a ${s.brightness} container',
        );
      }
    }
  });

  testWidgets('dark after sunset at home; accent colour applies', (
    tester,
  ) async {
    // A June morning: before 7, but the sun is long up in Belgrade.
    var now = DateTime(2026, 6, 21, 6, 30);
    await pumpApp(
      tester,
      size: const Size(800, 1600),
      overrides: [minuteClockProvider.overrideWith((ref) => now)],
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );

    await goTo(tester, AppRoutes.settingsSection('appearance'));
    await settle(tester, 2);
    await tapKey(tester, 'themeAutoDark');
    await settle(tester, 3);
    expect(
      container.read(effectiveThemeModeProvider),
      ThemeMode.dark,
      reason: 'no location: by the clock',
    );
    await container.read(homeLocationWeatherEnabledProvider.notifier).set((
      latitude: 44.8,
      longitude: 20.46,
    ));
    await settle(tester, 2);
    expect(container.read(effectiveThemeModeProvider), ThemeMode.light);
    now = DateTime(2026, 6, 21, 23, 30);
    container.invalidate(minuteClockProvider);
    await settle(tester, 4);
    expect(container.read(effectiveThemeModeProvider), ThemeMode.dark);

    await tapKey(tester, 'accent-teal');
    await settle(tester, 4);
    expect(container.read(accentProvider), AppAccent.teal);
    final primary = Theme.of(
      tester.element(find.byKey(const Key('themeAutoDark'))),
    ).colorScheme.primary;
    expect(
      primary,
      AppTheme.dark(accent: accentColor(AppAccent.teal)).colorScheme.primary,
    );
    await unmount(tester);
  });
}
