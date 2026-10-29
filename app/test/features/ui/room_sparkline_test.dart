import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../../widgets/app_widget_test.dart' show goTo, pumpApp, settle, unmount;

void main() {
  testWidgets('a room with a temperature sensor shows its last day', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.rooms);
    await settle(tester, 10);
    expect(
      find.byKey(const ValueKey('roomSparkline-living_room')),
      findsOneWidget,
    );
    // A room without a temperature sensor: no line.
    expect(find.byKey(const ValueKey('roomSparkline-garage')), findsNothing);
    await unmount(tester);
  });
}
