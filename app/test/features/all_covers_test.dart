import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('room with two blinds: close all, open all', (tester) async {
    final base = buildMockRegistries();
    final server = MockHomeAssistantServer(
      states: [
        ...buildMockStates(DateTime.now()),
        {
          'entity_id': 'cover.living_room_curtain',
          'state': 'open',
          'attributes': {
            'friendly_name': 'Zavesa dnevna soba',
            'device_class': 'curtain',
            'supported_features': 3,
          },
          'last_changed': DateTime.now().toUtc().toIso8601String(),
          'last_updated': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      registries: (
        areas: base.areas,
        devices: base.devices,
        entities: [
          ...base.entities,
          {
            'entity_id': 'cover.living_room_curtain',
            'platform': 'zha',
            'device_id': null,
            'area_id': 'living_room',
            'entity_category': null,
            'hidden_by': null,
            'disabled_by': null,
          },
        ],
      ),
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      server: server,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);

    await tapKey(tester, 'allCoversClose');
    await settle(tester, 6);
    expect(server.stateForTest('cover.living_room_blinds'), 'closed');
    expect(server.stateForTest('cover.living_room_curtain'), 'closed');

    await tapKey(tester, 'allCoversOpen');
    await settle(tester, 6);
    expect(server.stateForTest('cover.living_room_curtain'), 'open');
    await unmount(tester);
  });

  testWidgets('one blind alone gets no group buttons', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    expect(find.byKey(const Key('allCoversClose')), findsNothing);
    await unmount(tester);
  });
}
