import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_camera_image.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

MockHomeAssistantServer serverOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
        .read(mockHomeAssistantServerProvider);

void main() {
  testWidgets('mock camera frames are valid PNG images', (tester) async {
    final bytes = mockCameraFrame(1, DateTime(2026, 10, 13, 12, 0, 30));
    final size = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return (frame.image.width, frame.image.height);
    });
    expect(size, (320, 180));
  });

  testWidgets(
    'camera screen refreshes snapshots only while it is open; full screen',
    (tester) async {
      await pumpApp(tester, signedIn: true, size: const Size(900, 1200));
      await settle(tester, 10);
      final server = serverOf(tester);
      final before = server.cameraRequests;

      await goTo(tester, AppRoutes.device('camera.front_yard'));
      await settle(tester, 4);
      expect(find.byKey(const Key('cameraImage')), findsOneWidget);
      expect(find.text(en.cameraRefreshHint(2)), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        server.cameraRequests - before,
        greaterThanOrEqualTo(2),
        reason: 'refreshes every 2 s',
      );

      await tapKey(tester, 'cameraFullscreen');
      await settle(tester, 4);
      expect(find.byKey(const Key('cameraFullscreenView')), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await settle(tester, 2);

      await goTo(tester, AppRoutes.home);
      await settle(tester, 4);
      final stopped = server.cameraRequests;
      await tester.pump(const Duration(seconds: 10));
      expect(server.cameraRequests, stopped, reason: 'no background polling');
      await unmount(tester);
    },
  );

  testWidgets('live mode falls back to a message when there is no stream', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(900, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('camera.front_yard'));
    await settle(tester, 4);
    expect(
      find.byKey(const Key('cameraMode')),
      findsNothing,
      reason: 'camera without stream support',
    );
    await goTo(tester, AppRoutes.device('camera.driveway'));
    await settle(tester, 4);
    await tester.tap(find.text(en.cameraLive));
    await settle(tester, 6);
    expect(find.byKey(const Key('cameraLiveFailed')), findsOneWidget);
    await tester.tap(find.text(en.cameraSnapshots));
    await settle(tester, 4);
    expect(find.byKey(const Key('cameraImage')), findsOneWidget);
    await unmount(tester);
  });
}
