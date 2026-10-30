import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';
import 'package:open_smart_home_lite/features/weather/application/weather_providers.dart';
import 'package:open_smart_home_lite/features/weather/domain/weather.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, unmount;

void main() {
  test('the morning window, also across midnight', () {
    const s = KioskSettings(morningFrom: 6 * 60, morningTo: 10 * 60);
    expect(s.isMorning(DateTime(2026, 10, 17, 7)), isTrue);
    expect(s.isMorning(DateTime(2026, 10, 17, 10)), isFalse);
    expect(
      const KioskSettings(morningScreen: false)
          .isMorning(DateTime(2026, 10, 17, 7)),
      isFalse,
    );
    const late = KioskSettings(morningFrom: 23 * 60, morningTo: 1 * 60);
    expect(late.isMorning(DateTime(2026, 10, 17, 0, 30)), isTrue);
    final back = KioskSettings.fromJson(
      const KioskSettings(
        aodFocus: AodFocus.device,
        aodEntityId: 'fx:sensor.living_room_temperature',
      ).toJson(),
    );
    expect(back.aodFocus, AodFocus.device);
    expect(back.aodEntityId, 'fx:sensor.living_room_temperature');
  });

  Future<ProviderContainer> start(
    WidgetTester tester,
    KioskSettings Function(KioskSettings) setup,
  ) async {
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(1600, 1000),
      overrides: [
        homeWeatherProvider.overrideWithValue(
          const WeatherReport(
            source: WeatherSource.homeLocation,
            now: WeatherNow(
              condition: WeatherCondition.partlyCloudy,
              temperature: 14,
            ),
          ),
        ),
      ],
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => setup(s.copyWith(dimAfter: const Duration(seconds: 5))));
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 8);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, 8);
    return container;
  }

  testWidgets('always-on: clock, weather and the chosen device', (
    tester,
  ) async {
    await start(
      tester,
      (s) => s.copyWith(
        morningScreen: false,
        aodFocus: AodFocus.device,
        aodEntityId: 'fx:sensor.living_room_temperature',
      ),
    );
    expect(find.byKey(const Key('kioskScreensaver')), findsOneWidget);
    expect(find.byKey(const Key('aodClock')), findsOneWidget);
    expect(find.byKey(const Key('aodWeather')), findsOneWidget);
    expect(find.textContaining('Temperatura dnevna soba'), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskScreensaver')), findsNothing);
    await unmount(tester);
  });

  testWidgets('morning: greeting, clock and the weather', (tester) async {
    // A window around now, whatever time the test runs.
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    await start(
      tester,
      (s) => s.copyWith(
        morningScreen: true,
        morningFrom: (m - 60) % (24 * 60),
        morningTo: (m + 60) % (24 * 60),
      ),
    );
    expect(find.byKey(const Key('aodMorning')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('aodMorning')),
        matching: find.text(en.greetingMorning),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('aodWeather')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('night: red clock, first tap is the night light', (tester) async {
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    await start(
      tester,
      (s) => s.copyWith(
        nightBrightness: true,
        nightFrom: (m - 60) % (24 * 60),
        nightTo: (m + 60) % (24 * 60),
        nightClock: true,
        nightLightId: 'fx:light.hallway',
      ),
    );
    final server = HomeFixture.running;
    expect(server.stateOf('fx:light.hallway'), 'off');
    expect(find.byKey(const Key('aodNight')), findsOneWidget);
    expect(find.text(en.kioskNightLightHint('Hodnik')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 4);
    expect(server.stateOf('fx:light.hallway'), 'on');
    expect(find.byKey(const Key('kioskScreensaver')), findsOneWidget);
    expect(find.text(en.kioskNightLightOn('Hodnik')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskScreensaver')), findsNothing);
    await unmount(tester);
  });
}
