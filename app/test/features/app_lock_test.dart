import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/app_lock/application/app_lock.dart';
import 'package:open_smart_home_lite/features/app_lock/data/device_auth.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)));

void main() {
  test('settings round-trip', () {
    final s = AppLockSettings.fromJson(
      const AppLockSettings(lockApp: true, confirmCritical: true).toJson(),
    );
    expect((s.lockApp, s.confirmCritical), (true, true));
    expect(AppLockSettings.fromJson(null).lockApp, isFalse);
  });

  testWidgets('lock the app: enable (with a check), lock, unlock', (
    tester,
  ) async {
    final auth = FakeDeviceAuth();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      deviceAuth: auth,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('security'));
    await tapKey(tester, 'appLockSwitch');
    await settle(tester, 2);
    expect(auth.prompts, 1, reason: 'proves it works before enabling');
    final container = containerOf(tester);
    expect(container.read(appLockSettingsProvider).lockApp, isTrue);

    auth.passes = false;
    container.read(appLockProvider.notifier).lockNow();
    await settle(tester, 2);
    expect(find.byKey(const Key('appLockScreen')), findsOneWidget);
    expect(find.text(en.appLockTitle), findsOneWidget);

    auth.passes = true;
    await tester.tap(find.byKey(const Key('appUnlock')));
    await settle(tester, 2);
    expect(find.byKey(const Key('appLockScreen')), findsNothing);
    await unmount(tester);
  });

  testWidgets('unlocking a door also asks for fingerprint when enabled', (
    tester,
  ) async {
    final auth = FakeDeviceAuth(passes: false);
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      deviceAuth: auth,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('security'));
    await tapKey(tester, 'appLockCriticalSwitch');
    await settle(tester, 2);
    await goTo(tester, AppRoutes.device('lock.front_door'));
    await settle(tester, 4);
    await tapKey(tester, 'unlockButton');
    await settle(tester, 2);
    await tapKey(tester, 'confirmCriticalAction');
    await settle(tester, 6);
    expect(auth.prompts, 1);
    expect(
      find.text(en.lockLocked),
      findsWidgets,
      reason: 'failed check: the door stays locked',
    );
    await unmount(tester);
  });
}
