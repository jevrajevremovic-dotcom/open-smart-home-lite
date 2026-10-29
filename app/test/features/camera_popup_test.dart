import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('pop-up settings survive storage; unknown durations fall back', () {
    const s = KioskSettings(
      popupCameraId: 'camera.front_yard',
      popupTriggerIds: ['binary_sensor.front_door'],
      popupSeconds: 120,
    );
    final back = KioskSettings.fromJson(s.toJson());
    expect(back.hasPopup, isTrue);
    expect(back.popupSeconds, 120);
    expect(
      KioskSettings.fromJson({...s.toJson(), 'popupSeconds': 7}).popupSeconds,
      60,
    );
  });

  testWidgets('a door opening pops up the camera over the kiosk', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 800));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'kioskPopup');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('kioskPopupCamera')));
    await settle(tester, 2);
    await tester.tap(find.text('Kamera bašta').last);
    await settle(tester, 2);
    await tester.tap(
      find.byKey(const ValueKey('kioskPopupTrigger-binary_sensor.front_door')),
    );
    await tester.tap(find.byKey(const Key('kioskPopupSave')));
    await settle(tester, 3);
    expect(find.textContaining('Kamera bašta'), findsWidgets);

    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    expect(find.byKey(const Key('kioskCameraPopup')), findsNothing);

    server.setStateForTest('binary_sensor.front_door', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskCameraPopup')), findsOneWidget);
    expect(find.text('Ulazna vrata'), findsWidgets);
    // The mock offers no stream: snapshots stand in for the live video.
    expect(find.byKey(const Key('cameraLiveFallback')), findsOneWidget);
    await tester.tap(find.byKey(const Key('kioskPopupClose')));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskCameraPopup')), findsNothing);

    // Closing and opening again pops it up again, and it closes itself.
    server.setStateForTest('binary_sensor.front_door', 'off');
    await settle(tester, 2);
    server.setStateForTest('binary_sensor.front_door', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskCameraPopup')), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskCameraPopup')), findsNothing);
    await unmount(tester);
  });
}
