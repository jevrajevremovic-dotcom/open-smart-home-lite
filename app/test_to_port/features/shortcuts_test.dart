import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeShortcuts;

import 'package:open_smart_home_lite/features/household/family_messages.dart';

import '../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

void main() {
  testWidgets('launcher shortcuts: scene, house check, Assist and kiosk', (
    tester,
  ) async {
    final shortcuts = FakeShortcuts();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      shortcuts: shortcuts,
    );
    await settle(tester, 10);
    expect(shortcuts.items.map((i) => i.$1), [
      'scene:scene.movie_night',
      'check',
      'coming',
      'assist',
      'kiosk',
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    final before = server.states.firstWhere(
      (s) => s['entity_id'] == 'scene.movie_night',
    )['state'];

    shortcuts.tap('scene:scene.movie_night');
    await settle(tester, 6);
    final after = server.states.firstWhere(
      (s) => s['entity_id'] == 'scene.movie_night',
    )['state'];
    expect(after, isNot(before), reason: 'scene activated');

    shortcuts.tap('check');
    await settle(tester, 6);
    expect(find.byKey(const Key('houseCheckMode')), findsOneWidget);

    shortcuts.tap('coming');
    await settle(tester, 6);
    expect(
      container.read(familyMessagesProvider).map((m) => m.text),
      contains(en.comingHomeMessageNoName),
    );

    shortcuts.tap('assist');
    await settle(tester, 6);
    expect(find.byKey(const Key('assistSheet')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('assistSheet')))).pop();
    await settle(tester, 6);

    shortcuts.tap('kiosk');
    await settle(tester, 8);
    expect(container.read(kioskActiveProvider), isTrue);
    expect(find.byKey(const Key('kioskExit')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'a launcher link for anything not on the shortcuts does nothing',
    (tester) async {
      final shortcuts = FakeShortcuts();
      await pumpApp(
        tester,
        signedIn: true,
        size: const Size(800, 1400),
        shortcuts: shortcuts,
      );
      await settle(tester, 10);
      // Another app starting this one with a made-up shortcut: an automation
      // (it could as well be a garage door button).
      shortcuts.tap('scene:automation.hallway_night_light');
      await settle(tester, 6);
      expect(
        find.text(en.sceneActivated('Noćno svetlo u hodniku')),
        findsNothing,
      );
      // The real one still works.
      shortcuts.tap('scene:scene.movie_night');
      await settle(tester, 6);
      expect(find.text(en.sceneActivated('Filmsko veče')), findsOneWidget);
      await unmount(tester);
    },
  );
}
