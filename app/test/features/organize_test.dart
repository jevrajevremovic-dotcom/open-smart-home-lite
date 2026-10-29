import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/favorites/application/favorites_controller.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('rename a device and move it to another room', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('switch.coffee_machine'));
    await settle(tester, 4);
    await tapKey(tester, 'editDevice');
    await settle(tester, 2);
    await tester.enterText(
      find.byKey(const Key('setUpName')),
      'Espreso aparat',
    );
    await tester.tap(find.byKey(const Key('setUpRoom')));
    await settle(tester, 2);
    await tester.tap(find.text('Hodnik').last);
    await settle(tester, 2);
    await tapKey(tester, 'setUpSave');
    await settle(tester, 8);
    expect(find.text(en.setUpSaved), findsOneWidget);
    expect(find.text('Espreso aparat'), findsWidgets);

    await goTo(tester, AppRoutes.room('hallway'));
    await settle(tester, 4);
    expect(find.text('Espreso aparat'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('search all devices by name, room or type', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.allDevices);
    await settle(tester, 2);
    await tester.enterText(
      find.byKey(const Key('deviceSearch')),
      'dnevna svetl',
    );
    await settle(tester, 2);
    expect(find.text('Dnevna soba – glavno svetlo'), findsOneWidget);
    expect(find.text('Hodnik'), findsNothing);
    await tester.enterText(find.byKey(const Key('deviceSearch')), 'zzzz');
    await settle(tester, 2);
    expect(find.text(en.deviceSearchEmpty), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('reorder favorites', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final favorites = container.read(favoritesProvider.notifier);
    await favorites.toggle('light.living_room_main');
    await favorites.toggle('switch.tv_outlet');
    await favorites.toggle('lock.front_door');
    await goTo(tester, AppRoutes.favorites);
    await settle(tester, 4);
    await tapKey(tester, 'reorderFavorites');
    await settle(tester, 4);
    final handle = find.byIcon(Icons.drag_handle).last;
    await tester.drag(handle, const Offset(0, -300));
    await settle(tester, 6);
    expect(container.read(favoritesProvider).first, 'lock.front_door');
    await unmount(tester);
  });

  testWidgets('rooms are grouped by floor when HA has floors', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.rooms);
    await settle(tester, 4);
    final ground = tester.getTopLeft(
      find.byKey(const ValueKey('floor-Prizemlje')),
    );
    final first = tester.getTopLeft(find.byKey(const ValueKey('floor-Sprat')));
    final other = tester.getTopLeft(
      find.byKey(ValueKey('floor-${en.floorOther}')),
    );
    expect(ground.dy < first.dy && first.dy < other.dy, isTrue);
    await unmount(tester);
  });
}
