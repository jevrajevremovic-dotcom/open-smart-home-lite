import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

Future<void> startKiosk(WidgetTester tester) async {
  await goTo(tester, AppRoutes.settingsSection('kiosk'));
  await tapKey(tester, 'startKiosk');
  await settle(tester, 20);
}

/// Scrolls the kiosk's home overview to [f].
Future<void> showOnHome(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('kioskColumnsOverview')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets('kiosk without weather offers the home-location forecast', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1600, 1000));
    await settle(tester, 10);
    await startKiosk(tester);
    // No forecast yet: the home-location forecast is offered.
    await showOnHome(tester, find.byKey(const Key('homeWeatherPrompt')));
    expect(find.byKey(const Key('homeWeatherPrompt')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('home-location forecast after consent, shown in the kiosk', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1600, 1000));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('privacy'));
    await tapKey(tester, 'homeWeatherSwitch');
    await settle(tester, 2);
    expect(find.text(en.weatherHomeLocationDisclosure), findsOneWidget);
    await tapKey(tester, 'confirmHomeWeather');
    await settle(tester, 4);
    await startKiosk(tester);
    await showOnHome(tester, find.text(en.weatherMetAttribution));
    expect(find.text(en.weatherMetAttribution), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('media sheet: switch player, power on, choose a source', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1600, 1000));
    await settle(tester, 10);
    await startKiosk(tester);
    await showOnHome(tester, find.byKey(const Key('nowPlayingCard')));
    await tapKey(tester, 'nowPlayingCard');
    await settle(tester, 2);
    expect(find.byKey(const Key('mediaSheet')), findsOneWidget);
    expect(find.text('Kafa i kiša'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('mediaPlayer-fx:media_player.living_room_tv')),
    );
    await settle(tester, 2);
    await tapKey(tester, 'mediaPower');
    await settle(tester, 4);
    await tapKey(tester, 'mediaSource');
    await settle(tester, 2);
    await tester.tap(find.text('HDMI 1').last);
    await settle(tester, 4);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('mediaSource')),
          )
          .initialValue,
      'HDMI 1',
    );
    await unmount(tester);
  });

  testWidgets('music card is there even without media players and explains', (
    tester,
  ) async {
    await pumpApp(
      tester,
      adapter: HomeFixture(
        devices: [
          for (final d in fixtureDevices(DateTime.now()))
            if (!d.id.startsWith('fx:media_player.')) d,
        ],
      ),
      size: const Size(800, 1600),
    );
    await settle(tester, 10);
    final card = find.byKey(const Key('nowPlayingCard'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(en.mediaNoPlayersShort)),
      findsOneWidget,
    );
    await tester.tap(card);
    await settle(tester, 3);
    expect(find.text(en.mediaNoPlayers), findsOneWidget);
    await unmount(tester);
  });
}
