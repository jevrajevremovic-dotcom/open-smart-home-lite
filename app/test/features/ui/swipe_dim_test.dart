import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

void main() {
  testWidgets('sideways on a light card: on and brighter, then off', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    final card = find.byKey(const ValueKey('tileSwipe-light.living_room_main'));
    expect(server.stateForTest('light.living_room_main'), 'on');
    final width = tester.getSize(card).width;

    // All the way left: off.
    await tester.drag(card, Offset(-width * 1.2, 0));
    await settle(tester, 4);
    expect(server.stateForTest('light.living_room_main'), 'off');

    // From off, a bit more than half way right: on, about that bright.
    await tester.drag(card, Offset(width * 0.6, 0));
    await settle(tester, 4);
    expect(server.stateForTest('light.living_room_main'), 'on');
    final b = container
        .read(deviceProvider('light.living_room_main'))!
        .state
        .brightnessPercent!;
    expect(b, inInclusiveRange(40, 70));
    await unmount(tester);
  });
}
