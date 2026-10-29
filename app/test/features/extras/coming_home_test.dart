import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/extras/coming_home.dart';
import 'package:open_smart_home_lite/features/extras/vacation.dart';
import 'package:open_smart_home_lite/features/household/family_messages.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('coming home: scene, heating and a message for the household', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    final sceneBefore = server.stateForTest('scene.movie_night');
    await container
        .read(comingHomeProvider.notifier)
        .update(
          (_) => const ComingHome(
            personId: 'person.marko',
            routineId: 'scene.movie_night',
            temperature: 22,
          ),
        );

    await tapKey(tester, 'openExtras');
    await settle(tester, 2);
    await tapKey(tester, 'extraComingHome');
    await settle(tester, 2);
    await tapKey(tester, 'comingHomeRun');
    await settle(tester, 8);

    expect(find.text(en.comingHomeDone), findsOneWidget);
    expect(server.stateForTest('scene.movie_night'), isNot(sceneBefore));
    for (final t in vacationThermostats(
      container.read(homeSnapshotProvider).devices.values,
    )) {
      expect(t.state.targetTemperature, 22);
    }
    expect(
      container.read(familyMessagesProvider).map((m) => m.text),
      contains(en.comingHomeMessage('Marko')),
    );
    await unmount(tester);
  });
}
