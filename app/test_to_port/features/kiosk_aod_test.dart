import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';

import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

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
        aodFocus: AodFocus.list,
        aodEntityId: 'todo.shopping_list',
      ).toJson(),
    );
    expect(back.aodFocus, AodFocus.list);
    expect(back.aodEntityId, 'todo.shopping_list');
  });

  Future<ProviderContainer> start(
    WidgetTester tester,
    KioskSettings Function(KioskSettings) setup,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1600, 1000));
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

  testWidgets('always-on: clock, weather and the chosen list', (tester) async {
    await start(
      tester,
      (s) => s.copyWith(
        morningScreen: false,
        aodFocus: AodFocus.list,
        aodEntityId: 'todo.shopping_list',
      ),
    );
    expect(find.byKey(const Key('kioskScreensaver')), findsOneWidget);
    expect(find.byKey(const Key('aodClock')), findsOneWidget);
    expect(find.byKey(const Key('aodWeather')), findsOneWidget);
    expect(find.textContaining('Mleko'), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskScreensaver')), findsNothing);
    await unmount(tester);
  });

  testWidgets('morning: events of today and reminders due today', (
    tester,
  ) async {
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
      find.byKey(const ValueKey('aodReminder-Izneti smeće')),
      findsOneWidget,
    );
    // The demo's "Vrtić" is today 08:00–16:00; ended events are not shown.
    expect(
      find.byKey(const ValueKey('aodEvent-Vrtić')),
      now.hour < 16 ? findsOneWidget : findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('night: red clock, first tap is the night light', (tester) async {
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    final container = await start(
      tester,
      (s) => s.copyWith(
        nightBrightness: true,
        nightFrom: (m - 60) % (24 * 60),
        nightTo: (m + 60) % (24 * 60),
        nightClock: true,
        nightLightId: 'light.hallway',
      ),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    expect(server.stateForTest('light.hallway'), 'off');
    expect(find.byKey(const Key('aodNight')), findsOneWidget);
    expect(find.text(en.kioskNightLightHint('Hodnik')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 4);
    expect(server.stateForTest('light.hallway'), 'on');
    expect(find.byKey(const Key('kioskScreensaver')), findsOneWidget);
    expect(find.text(en.kioskNightLightOn('Hodnik')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskScreensaver')), findsNothing);
    await unmount(tester);
  });
}
