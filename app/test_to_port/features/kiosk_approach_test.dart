import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeApproach;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  const screensaver = Key('kioskScreensaver');

  Future<void> idle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, 6);
    expect(find.byKey(screensaver), findsOneWidget);
  }

  testWidgets('a Home Assistant motion sensor wakes the idle screen', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1600, 1000));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tester.ensureVisible(find.byKey(const Key('approachWake')));
    await tapKey(tester, 'approachWake');
    await settle(tester, 3);
    await tester.tap(find.text(en.approachSensor).last);
    await settle(tester, 3);
    await tester.tap(
      find.byKey(const ValueKey('approachPick-binary_sensor.hallway_motion')),
    );
    await settle(tester, 3);
    expect(
      container.read(kioskSettingsProvider).approachSensorId,
      'binary_sensor.hallway_motion',
    );

    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(dimAfter: const Duration(seconds: 5)));
    server.setStateForTest('binary_sensor.hallway_motion', 'off');
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    await idle(tester);

    server.setStateForTest('binary_sensor.hallway_motion', 'on');
    await settle(tester, 4);
    expect(find.byKey(screensaver), findsNothing, reason: 'woken');
    await unmount(tester);
  });

  testWidgets('front camera: only while idle, movement wakes the screen', (
    tester,
  ) async {
    final camera = FakeApproach();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1600, 1000),
      approach: camera,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tester.ensureVisible(find.byKey(const Key('approachWake')));
    await tapKey(tester, 'approachWake');
    await settle(tester, 3);
    await tester.tap(find.text(en.approachCamera).last);
    await settle(tester, 3);
    expect(find.text(en.approachCameraBody), findsOneWidget);
    await tapKey(tester, 'approachCameraAllow');
    await settle(tester, 3);
    expect(
      container.read(kioskSettingsProvider).approachWake,
      ApproachWake.camera,
    );

    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(dimAfter: const Duration(seconds: 5)));
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    expect(camera.listeners, 0, reason: 'camera off while awake');
    await idle(tester);
    expect(camera.listeners, 1);

    camera.move();
    await settle(tester, 4);
    expect(find.byKey(screensaver), findsNothing);
    expect(camera.listeners, 0, reason: 'camera off again');
    await unmount(tester);
  });

  test('settings survive a round trip', () {
    final back = KioskSettings.fromJson(
      const KioskSettings(
        approachWake: ApproachWake.sensor,
        approachSensorId: 'binary_sensor.x',
      ).toJson(),
    );
    expect(back.approachWake, ApproachWake.sensor);
    expect(back.approachSensorId, 'binary_sensor.x');
  });
}
