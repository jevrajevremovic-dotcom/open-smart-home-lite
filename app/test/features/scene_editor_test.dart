import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/automations/domain/scene_snapshot.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('scene entries keep brightness, colour and positions', () {
    final light = const HaDeviceMapper().map(
      const HaEntityState(
        entityId: 'light.a',
        state: 'on',
        attributes: {
          'supported_color_modes': ['color_temp'],
          'color_mode': 'color_temp',
          'brightness': 128,
          'color_temp_kelvin': 3000,
        },
      ),
      HaRegistries.empty,
    );
    expect(sceneEntryFor(light), {
      'state': 'on',
      'brightness': 128,
      'color_temp_kelvin': 3000,
    });
    final cover = const HaDeviceMapper().map(
      const HaEntityState(
        entityId: 'cover.b',
        state: 'open',
        attributes: {'current_position': 40, 'supported_features': 15},
      ),
      HaRegistries.empty,
    );
    expect(sceneEntryFor(cover), {'state': 'open', 'current_position': 40});
  });

  testWidgets('save the current lights as a scene and bring them back', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.scenes);
    await tapKey(tester, 'newScene');
    await settle(tester, 4);
    await tester.enterText(find.byKey(const Key('sceneName')), 'Veče');
    await tapKey(tester, 'sceneSave');
    await settle(tester, 8);
    expect(find.text(en.sceneSaved), findsOneWidget);
    // The demo home's own movie night is there too.
    final entities =
        server.scenes.values.singleWhere(
              (s) => s['name'] == 'Veče',
            )['entities']!
            as Map;
    expect(entities.keys, containsAll(['light.living_room_main']));

    server.callService('light', 'turn_off', {
      'entity_id': ['light.living_room_main', 'light.living_room_ambient'],
    });
    await settle(tester, 4);
    expect(find.text(en.lightsOnOf(0, 3)), findsNothing); // on scenes screen

    server.callService('scene', 'turn_on', {'entity_id': 'scene.vece'});
    await settle(tester, 6);
    await goTo(tester, AppRoutes.home);
    await settle(tester, 4);
    expect(find.text(en.lightsOnOf(2, 3)), findsOneWidget);
    await unmount(tester);
  });
}
