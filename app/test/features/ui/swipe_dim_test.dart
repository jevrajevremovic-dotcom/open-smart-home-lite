import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';

import '../../home_fixture.dart';
import '../../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

void main() {
  testWidgets('sideways on a light card: on and brighter, then off', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = HomeFixture.running;
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    final card = find.byKey(
      const ValueKey('tileSwipe-fx:light.living_room_main'),
    );
    expect(server.stateOf('fx:light.living_room_main'), 'on');
    final width = tester.getSize(card).width;

    // All the way left: off.
    await tester.drag(card, Offset(-width * 1.2, 0));
    await settle(tester, 4);
    expect(server.stateOf('fx:light.living_room_main'), 'off');

    // From off, a bit more than half way right: on, about that bright.
    await tester.drag(card, Offset(width * 0.6, 0));
    await settle(tester, 4);
    expect(server.stateOf('fx:light.living_room_main'), 'on');
    final b = container
        .read(deviceProvider('fx:light.living_room_main'))!
        .state
        .brightnessPercent!;
    expect(b, inInclusiveRange(40, 70));
    await unmount(tester);
  });
}
