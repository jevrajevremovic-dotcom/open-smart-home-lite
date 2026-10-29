import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('on the wall panel, unlocking the door also needs the PIN', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 800));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await container.read(kioskSettingsProvider.notifier).setPin('2468');
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.device('lock.front_door', kiosk: true));
    await settle(tester, 6);
    expect(server.stateForTest('lock.front_door'), 'locked');

    await tapKey(tester, 'unlockButton');
    await settle(tester, 2);
    await tapKey(tester, 'confirmCriticalAction');
    await settle(tester, 2);
    // Confirmed, but no PIN yet: still locked.
    expect(find.byKey(const Key('pinField')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pinField')), '1111');
    await tapKey(tester, 'pinSubmit');
    await settle(tester, 2);
    expect(find.text(en.kioskWrongPin), findsOneWidget);
    expect(server.stateForTest('lock.front_door'), 'locked');

    await tester.enterText(find.byKey(const Key('pinField')), '2468');
    await tapKey(tester, 'pinSubmit');
    await settle(tester, 8);
    expect(server.stateForTest('lock.front_door'), 'unlocked');
    await unmount(tester);
  });
}
