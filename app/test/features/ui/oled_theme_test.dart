import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/theme/app_theme.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';

import '../../widgets/app_widget_test.dart' show pumpApp, settle, unmount;

void main() {
  test('pure black page, darker cards, same accent', () {
    final oled = AppTheme.dark(oled: true).colorScheme;
    final dark = AppTheme.dark().colorScheme;
    expect(oled.surface, Colors.black);
    expect(
      oled.surfaceContainerHigh.computeLuminance(),
      lessThan(dark.surfaceContainerHigh.computeLuminance()),
    );
    expect(oled.primary, dark.primary);
  });

  testWidgets('the switch makes the dark theme black', (tester) async {
    await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 6);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await container.read(oledProvider.notifier).set(true);
    await settle(tester, 4);
    final scaffold = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffold).colorScheme.surface, Colors.black);
    await unmount(tester);
  });
}
