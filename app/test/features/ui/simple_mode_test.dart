import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/simple_mode/simple_mode.dart';

import '../../home_fixture.dart';
import '../../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('simple mode stays only on /simple', () {
    String? go(String location) =>
        resolveRedirect(location: location, simple: true);
    expect(go(AppRoutes.home), AppRoutes.simple);
    expect(go(AppRoutes.settings), AppRoutes.simple);
    expect(go(AppRoutes.simple), isNull);
  });

  testWidgets('choose buttons, use them, leave', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = HomeFixture.running;
    await goTo(tester, AppRoutes.settingsSection('security'));
    await settle(tester, 4);
    await tapKey(tester, 'simpleChoose');
    await settle(tester, 3);
    await tapKey(tester, 'simplePick-fx:light.living_room_main');
    await tapKey(tester, 'simplePick-fx:climate.living_room');
    await tapKey(tester, 'simplePickSave');
    await settle(tester, 3);
    expect(container.read(simpleModeProvider).items, [
      'fx:light.living_room_main',
      'fx:climate.living_room',
    ]);
    await tapKey(tester, 'simpleStart');
    await settle(tester, 4);
    expect(find.byKey(const Key('simpleMode')), findsOneWidget);

    // The rest of the app is out of reach.
    await goTo(tester, AppRoutes.rooms);
    await settle(tester, 3);
    expect(find.byKey(const Key('simpleMode')), findsOneWidget);

    await tapKey(tester, 'simpleTile-fx:light.living_room_main');
    await settle(tester, 3);
    expect(server.stateOf('fx:light.living_room_main'), 'off');

    final before = container
        .read(deviceProvider('fx:climate.living_room'))!
        .state
        .targetTemperature!;
    await tapKey(tester, 'simpleUp-fx:climate.living_room');
    await settle(tester, 3);
    expect(
      container
          .read(deviceProvider('fx:climate.living_room'))!
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
