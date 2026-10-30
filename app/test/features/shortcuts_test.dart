import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';

import '../home_fixture.dart';
import '../helpers.dart' show FakeShortcuts;

import '../widgets/app_widget_test.dart' show en, pumpApp, settle, unmount;

void main() {
  testWidgets('launcher shortcuts: scene, house check and kiosk', (
    tester,
  ) async {
    final shortcuts = FakeShortcuts();
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(800, 1400),
      shortcuts: shortcuts,
    );
    await settle(tester, 10);
    expect(shortcuts.items.map((i) => i.$1), [
      'scene:routine:scene_movie_night',
      'check',
      'kiosk',
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = HomeFixture.running;
    shortcuts.tap('scene:routine:scene_movie_night');
    await settle(tester, 6);
    expect(
      server.stateOf('light.living_room_main'),
      'off',
      reason: 'scene activated',
    );

    shortcuts.tap('check');
    await settle(tester, 6);
    expect(find.byKey(const Key('houseCheckMode')), findsOneWidget);

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
        adapter: HomeFixture(),
        size: const Size(800, 1400),
        shortcuts: shortcuts,
      );
      await settle(tester, 10);
      // Another app starting this one with a made-up shortcut: a lock
      // (it could as well be a garage door button).
      shortcuts.tap('scene:fx:lock.front_door');
      await settle(tester, 6);
      expect(HomeFixture.running.stateOf('lock.front_door'), 'locked');
      // The real one still works.
      shortcuts.tap('scene:routine:scene_movie_night');
      await settle(tester, 6);
      expect(find.text(en.sceneActivated('Filmsko veče')), findsOneWidget);
      await unmount(tester);
    },
  );
}
