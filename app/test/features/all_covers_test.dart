import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('room with two blinds: close all, open all', (tester) async {
    final server = HomeFixture();
    await pumpApp(tester, adapter: server, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);

    await tapKey(tester, 'allCoversClose');
    await settle(tester, 6);
    expect(server.stateOf('fx:cover.living_room_blinds'), 'closed');
    expect(server.stateOf('fx:cover.living_room_curtain'), 'closed');

    await tapKey(tester, 'allCoversOpen');
    await settle(tester, 6);
    expect(server.stateOf('fx:cover.living_room_curtain'), 'open');
    await unmount(tester);
  });

  testWidgets('one blind alone gets no group buttons', (tester) async {
    await pumpApp(
      tester,
      adapter: HomeFixture(
        devices: [
          for (final d in fixtureDevices(DateTime.now()))
            if (d.id != 'fx:cover.living_room_curtain') d,
        ],
      ),
      size: const Size(800, 1600),
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living_room'));
    await settle(tester, 4);
    expect(find.byKey(const Key('allCoversClose')), findsNothing);
    await unmount(tester);
  });
}
