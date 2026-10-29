import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('doorbell pop-up: "Coming!" at the door, "Unlock" confirmed', (
    tester,
  ) async {
    final now = DateTime.now();
    final server = MockHomeAssistantServer(
      states: [
        ...buildMockStates(now),
        {
          'entity_id': 'tts.piper',
          'state': 'unknown',
          'attributes': {'friendly_name': 'Piper'},
          'last_changed': now.toUtc().toIso8601String(),
          'last_updated': now.toUtc().toIso8601String(),
        },
      ],
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      server: server,
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await container
        .read(kioskSettingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            popupCameraId: 'camera.front_yard',
            popupTriggerIds: ['binary_sensor.front_door'],
            popupOpenId: 'lock.front_door',
            popupSpeakerId: 'media_player.living_room_speaker',
          ),
        );
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);

    server.setStateForTest('binary_sensor.front_door', 'on');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskCameraPopup')), findsOneWidget);

    await tapKey(tester, 'kioskIntercomReply');
    await settle(tester, 6);
    expect(server.lastTtsSpeak, {
      'entity_id': 'tts.piper',
      'media_player_entity_id': 'media_player.living_room_speaker',
      'message': en.kioskIntercomReplyText,
    });
    expect(find.text(en.kioskIntercomReplied), findsOneWidget);

    await tapKey(tester, 'kioskIntercomOpen');
    await settle(tester, 3);
    await tapKey(tester, 'confirmCriticalAction');
    await settle(tester, 6);
    expect(server.stateForTest('lock.front_door'), 'unlocked');
    expect(find.byKey(const Key('kioskCameraPopup')), findsNothing);
    await unmount(tester);
  });
}
