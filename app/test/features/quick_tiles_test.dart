import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
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
      adapter: HomeFixture(),
      size: const Size(800, 1600),
      tiles: tiles,
    );
    await settle(tester, 10);
    final server = HomeFixture.running;

    await goTo(tester, AppRoutes.settingsSection('appearance'));
    await settle(tester, 2);
    await tapKey(tester, 'quickTile-0');
    await settle(tester, 2);
    // A tap in a menu is no confirmation: no locks offered.
    expect(
      find.byKey(const ValueKey('quickTilePick-fx:lock.front_door')),
      findsNothing,
    );
    await tester.enterText(find.byKey(const Key('quickTileSearch')), 'Hodnik');
    await settle(tester, 1);
    await tapKey(tester, 'quickTilePick-fx:light.hallway');
    await settle(tester, 2);
    await tapKey(tester, 'quickTile-1');
    await settle(tester, 2);
    await tapKey(tester, 'quickTilePick-routine:scene_movie_night');
    await settle(tester, 2);

    expect(tiles.shown[0]?.label, 'Hodnik');
    expect(tiles.shown[0]?.active, isFalse);
    expect(tiles.shown[1]?.active, isNull, reason: 'a scene does not stay on');
    expect(tiles.shown[2], isNull);

    tiles.tap(0);
    await settle(tester, 6);
    expect(server.stateOf('fx:light.hallway'), 'on');
    expect(tiles.shown[0]?.active, isTrue, reason: 'the menu follows');

    tiles.tap(1);
    await settle(tester, 6);
    expect(
      server.stateOf('fx:light.living_room_main'),
      'off',
      reason: 'the scene ran',
    );

    await tapKey(tester, 'quickTileAdd-0');
    await settle(tester, 2);
    expect(tiles.addRequests, 1);
    expect(find.text(en.quickTileAdded), findsOneWidget);
    await unmount(tester);
  });
}
