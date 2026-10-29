import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/simple_mode/simple_mode.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('simple mode stays only on /simple', () {
    String? go(String location) => resolveRedirect(
      location: location,
      sessionLoading: false,
      signedIn: true,
      serverChosen: true,
      simple: true,
    );
    expect(go(AppRoutes.home), AppRoutes.simple);
    expect(go(AppRoutes.settings), AppRoutes.simple);
    expect(go(AppRoutes.simple), isNull);
  });

  testWidgets('choose buttons, use them, leave', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.settingsSection('security'));
    await settle(tester, 4);
    await tapKey(tester, 'simpleChoose');
    await settle(tester, 3);
    await tapKey(tester, 'simplePick-light.living_room_main');
    await tapKey(tester, 'simplePick-climate.living_room');
    await tapKey(tester, 'simplePickSave');
    await settle(tester, 3);
    expect(container.read(simpleModeProvider).items, [
      'light.living_room_main',
      'climate.living_room',
    ]);
    await tapKey(tester, 'simpleStart');
    await settle(tester, 4);
    expect(find.byKey(const Key('simpleMode')), findsOneWidget);

    // The rest of the app is out of reach.
    await goTo(tester, AppRoutes.rooms);
    await settle(tester, 3);
    expect(find.byKey(const Key('simpleMode')), findsOneWidget);

    await tapKey(tester, 'simpleTile-light.living_room_main');
    await settle(tester, 3);
    expect(server.stateForTest('light.living_room_main'), 'off');

    final before = container
        .read(deviceProvider('climate.living_room'))!
        .state
        .targetTemperature!;
    await tapKey(tester, 'simpleUp-climate.living_room');
    await settle(tester, 3);
    expect(
      container
          .read(deviceProvider('climate.living_room'))!
          .state
          .targetTemperature,
      before + 0.5,
    );

    await tapKey(tester, 'simpleLeave');
    await settle(tester, 2);
    await tapKey(tester, 'simpleLeaveConfirm');
    await settle(tester, 4);
    expect(find.byKey(const Key('simpleMode')), findsNothing);
    await unmount(tester);
  });
}
