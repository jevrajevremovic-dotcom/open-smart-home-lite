import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/presentation/kiosk_columns.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';
import 'package:open_smart_home_lite/features/weather/presentation/weather_card.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  Future<ProviderContainer> kiosk(WidgetTester tester, Size size) async {
    await pumpApp(tester, adapter: HomeFixture(), size: size);
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    return container;
  }

  testWidgets('rooms on the left, devices in the middle, details right', (
    tester,
  ) async {
    await kiosk(tester, const Size(1600, 1000));
    final server = HomeFixture.running;
    expect(find.byKey(const Key('kioskColumns')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsRoom-living_room')),
    );
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsRoomTitle'))).data,
      'Dnevna soba',
    );
    // The room's climate is shown on the right, with the big dial.
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsDetailName'))).data,
      'Klima dnevna soba',
    );
    await tapKey(tester, 'kioskIncreaseTemperature');
    await settle(tester, 20);
    expect(server['climate.living_room'].state.targetTemperature, 23.5);

    // The light's round icon switches it; the card shows it on the right.
    expect(server.stateOf('fx:light.living_room_main'), 'on');
    await tester.tap(
      find.byKey(
        const ValueKey('kioskColumnsToggle-fx:light.living_room_main'),
      ),
    );
    await settle(tester, 4);
    expect(server.stateOf('fx:light.living_room_main'), 'off');
    await tester.tap(
      find.byKey(
        const ValueKey('kioskColumnsDevice-fx:light.living_room_main'),
      ),
    );
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsDetailName'))).data,
      'Dnevna soba – glavno svetlo',
    );

    // Another room.
    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsRoomTitle'))).data,
      'Kuhinja',
    );

    // A scene from the left.
    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsScene-routine:scene_movie_night')),
    );
    await settle(tester, 4);
    await unmount(tester);
  });

  testWidgets('portrait: no right column, details in a sheet', (tester) async {
    await kiosk(tester, const Size(1000, 1400));
    expect(find.byKey(const Key('kioskColumns')), findsOneWidget);
    expect(find.byKey(const Key('kioskColumnsDetail')), findsNothing);
    // The quick controls move to the end of the home overview.
    await tester.scrollUntilVisible(
      find.byKey(const Key('kioskQuickControls')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('kioskColumnsOverview')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('kioskQuickControls')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('kioskColumnsRoom-living_room')),
    );
    await settle(tester, 4);
    await tester.tap(
      find.byKey(
        const ValueKey('kioskColumnsDevice-group:d_living_climate_sensor'),
      ),
    );
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskColumnsDetail')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kioskBundle-group:d_living_climate_sensor')),
      findsOneWidget,
    );
    // Closed: back to the room, nothing chosen.
    await tester.tapAt(const Offset(500, 40));
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskColumnsDetail')), findsNothing);
    expect(find.byKey(const Key('kioskColumnsRoomTitle')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('phone-sized: rooms from the menu', (tester) async {
    await kiosk(tester, const Size(600, 1000));
    expect(find.byKey(const Key('kioskColumnsOverview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kioskColumnsRoom-kitchen')),
      findsNothing,
    );
    await tapKey(tester, 'kioskColumnsMenu');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsRoomTitle'))).data,
      'Kuhinja',
    );
    // The drawer closed by itself.
    expect(
      find.byKey(const ValueKey('kioskColumnsRoom-kitchen')),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('home overview first: weather and music; back to it', (
    tester,
  ) async {
    final container = await kiosk(tester, const Size(1600, 1000));
    expect(find.byKey(const Key('kioskColumnsOverview')), findsOneWidget);
    // Weather, then music.
    final overview = find
        .descendant(
          of: find.byKey(const Key('kioskColumnsOverview')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final f in [
      find.byType(WeatherSection),
      find.byKey(const Key('nowPlayingCard')),
    ]) {
      await tester.scrollUntilVisible(f, 300, scrollable: overview);
      expect(f, findsOneWidget);
    }
    // The home's thermostat on the right.
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsDetailName'))).data,
      'Klima dnevna soba',
    );

    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskColumnsOverview')), findsNothing);
    await tapKey(tester, 'kioskColumnsHome');
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskColumnsOverview')), findsOneWidget);

    // Left alone in a room, it goes back to the overview.
    await tester.tap(find.byKey(const ValueKey('kioskColumnsRoom-kitchen')));
    await settle(tester, 4);
    await tester.pump(container.read(kioskSettingsProvider).returnHomeAfter);
    await settle(tester, 4);
    expect(find.byKey(const Key('kioskColumnsOverview')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('quick controls: choose a light and a scene, use them', (
    tester,
  ) async {
    final container = await kiosk(tester, const Size(1600, 1000));
    final server = HomeFixture.running;
    expect(find.byKey(const Key('kioskQuickControls')), findsOneWidget);
    await tapKey(tester, 'kioskQuickControlsEdit');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('kioskQuickSearch')), 'hodnik');
    await settle(tester, 2);
    await tester.tap(
      find.byKey(const ValueKey('kioskQuickPick-fx:light.hallway')),
    );
    await tester.enterText(find.byKey(const Key('kioskQuickSearch')), 'Film');
    await settle(tester, 2);
    await tester.tap(
      find.byKey(const ValueKey('kioskQuickPick-routine:scene_movie_night')),
    );
    await tapKey(tester, 'kioskQuickSave');
    await settle(tester, 3);
    expect(container.read(kioskSettingsProvider).quickControls, [
      'fx:light.hallway',
      'routine:scene_movie_night',
    ]);
    expect(find.byKey(const ValueKey('kioskQuick-fx:light.hallway')), findsOne);
    expect(
      find.byKey(const ValueKey('kioskQuick-routine:scene_movie_night')),
      findsOne,
    );

    expect(server.stateOf('fx:light.hallway'), 'off');
    await tapKey(tester, 'kioskQuickSwitch-fx:light.hallway');
    await settle(tester, 4);
    expect(server.stateOf('fx:light.hallway'), 'on');
    await unmount(tester);
  });

  testWidgets('devices without a room are reachable from the left', (
    tester,
  ) async {
    await kiosk(tester, const Size(1600, 1000));
    final none = find.byKey(const ValueKey('kioskColumnsRoom-none'));
    await tester.ensureVisible(none);
    await tester.tap(none);
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('kioskColumnsRoomTitle'))).data,
      en.roomNoRoom,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'kioskColumnsDevice-',
            ),
      ),
      findsWidgets,
    );
    await unmount(tester);
  });

  test('home cards: order and choice survive a round trip', () {
    final s = KioskSettings.fromJson(
      const KioskSettings(homeCards: [HomeCard.floorPlan, HomeCard.media])
          .toJson(),
    );
    expect(s.homeCards, [HomeCard.floorPlan, HomeCard.media]);
    expect(const KioskSettings().homeCards, HomeCard.values);
  });

  testWidgets('home cards can be hidden from the overview', (tester) async {
    final container = await kiosk(tester, const Size(1600, 1000));
    expect(find.byType(WeatherSection), findsOneWidget);
    await tapKey(tester, 'kioskHomeCardsEdit');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('kioskHomeCard-weather')));
    await tapKey(tester, 'kioskHomeCardsSave');
    await settle(tester, 3);
    expect(container.read(kioskSettingsProvider).homeCards, [
      HomeCard.media,
      HomeCard.floorPlan,
    ]);
    expect(find.byType(WeatherSection), findsNothing);
    expect(find.byKey(const Key('nowPlayingCard')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('swiping the middle goes room by room, Home first', (
    tester,
  ) async {
    final container = await kiosk(tester, const Size(1600, 1000));
    final rooms = container.read(roomsProvider);
    final swipe = find.byKey(const Key('kioskColumnsSwipe'));
    await tester.fling(swipe, const Offset(-400, 0), 1500);
    await settle(tester, 4);
    expect(container.read(kioskColumnsRoomProvider), rooms.first.id);
    await tester.fling(swipe, const Offset(-400, 0), 1500);
    await settle(tester, 4);
    expect(container.read(kioskColumnsRoomProvider), rooms[1].id);
    await tester.fling(swipe, const Offset(400, 0), 1500);
    await settle(tester, 4);
    await tester.fling(swipe, const Offset(400, 0), 1500);
    await settle(tester, 4);
    expect(container.read(kioskColumnsRoomProvider), isNull);
    expect(find.byKey(const Key('kioskColumnsOverview')), findsOneWidget);
    // Nothing before Home.
    await tester.fling(swipe, const Offset(400, 0), 1500);
    await settle(tester, 4);
    expect(container.read(kioskColumnsRoomProvider), isNull);
    await unmount(tester);
  });
}
