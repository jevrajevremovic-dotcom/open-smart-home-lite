import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeQuickTiles;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('choose tiles, the menu shows them, a tap switches', (
    tester,
  ) async {
    final tiles = FakeQuickTiles();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      tiles: tiles,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('appearance'));
    await settle(tester, 2);
    await tapKey(tester, 'quickTile-0');
    await settle(tester, 2);
    // A tap in a menu is no confirmation: no locks offered.
    expect(
      find.byKey(const ValueKey('quickTilePick-lock.front_door')),
      findsNothing,
    );
    await tester.enterText(find.byKey(const Key('quickTileSearch')), 'Hodnik');
    await settle(tester, 1);
    await tapKey(tester, 'quickTilePick-light.hallway');
    await settle(tester, 2);
    await tapKey(tester, 'quickTile-1');
    await settle(tester, 2);
    await tapKey(tester, 'quickTilePick-scene.movie_night');
    await settle(tester, 2);

    expect(tiles.shown[0]?.label, 'Hodnik');
    expect(tiles.shown[0]?.active, isFalse);
    expect(tiles.shown[1]?.active, isNull, reason: 'a scene does not stay on');
    expect(tiles.shown[2], isNull);

    tiles.tap(0);
    await settle(tester, 6);
    expect(server.stateForTest('light.hallway'), 'on');
    expect(tiles.shown[0]?.active, isTrue, reason: 'the menu follows');

    final before = server.stateForTest('scene.movie_night');
    tiles.tap(1);
    await settle(tester, 6);
    expect(server.stateForTest('scene.movie_night'), isNot(before));

    await tapKey(tester, 'quickTileAdd-0');
    await settle(tester, 2);
    expect(tiles.addRequests, 1);
    expect(find.text(en.quickTileAdded), findsOneWidget);
    await unmount(tester);
  });
}
