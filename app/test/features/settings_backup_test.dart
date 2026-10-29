import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/favorites/application/favorites_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/settings/application/appearance_controllers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('copy settings, change them, paste them back; no secrets', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await c.read(favoritesProvider.notifier).toggle('light.hallway');
    await c
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(quickControls: ['light.hallway']));
    await c.read(kioskSettingsProvider.notifier).setPin('1234');

    await goTo(tester, AppRoutes.settingsSection('backup'));
    await tapKey(tester, 'backupCopy');
    await settle(tester, 2);
    expect(clipboard, contains('"quickControls"'));
    expect(clipboard, isNot(contains('pinHash')));
    expect(clipboard, isNot(contains('token')));

    await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    await c.read(favoritesProvider.notifier).toggle('light.hallway');
    await c
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(quickControls: []));
    await settle(tester, 2);

    await tapKey(tester, 'backupPaste');
    await settle(tester, 4);
    expect(find.text(en.backupImported), findsOneWidget);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(c.read(favoritesProvider), contains('light.hallway'));
    expect(c.read(kioskSettingsProvider).quickControls, ['light.hallway']);
    expect(c.read(kioskSettingsProvider).hasPin, isTrue, reason: 'PIN kept');

    clipboard = 'hello';
    await tapKey(tester, 'backupPaste');
    await settle(tester, 4);
    expect(find.text(en.backupInvalid), findsOneWidget);
    await unmount(tester);
  });
}
