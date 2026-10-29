import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import 'app_widget_test.dart' show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('dashboard shows summary, scenes and rooms from real data', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 2200));
    await settle(tester, 10);
    expect(find.text(en.summaryTemperature), findsOneWidget);
    // One temperature sensor: in the summary and big on its room's card.
    expect(find.text('22.4°'), findsNWidgets(2));
    expect(find.text(en.lightsOnOf(2, 3)), findsOneWidget);
    expect(find.text('Filmsko veče'), findsOneWidget); // scene chip
    expect(find.text('Spavaća soba'), findsOneWidget); // room card
    expect(
      find.text(en.dashboardAttention),
      findsOneWidget,
    ); // low battery + unavailable
    await unmount(tester);
  });

  testWidgets('light detail: capability-driven controls and power toggle', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('light.living_room_main'));

    expect(find.text(en.brightness), findsOneWidget);
    expect(find.text(en.colorTemperature), findsOneWidget);
    expect(find.text(en.color), findsNothing, reason: 'no RGB capability');
    expect(find.text('Signify'), findsOneWidget);
    expect(find.text('Zigbee'), findsOneWidget);

    await tapKey(tester, 'powerSwitch');
    await settle(tester, 5);
    // State comes back from the (mock) server via state_changed.
    expect(find.text(en.stateOff), findsWidgets);
    await unmount(tester);
  });

  testWidgets('on/off-only light has no brightness slider', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('light.hallway'));
    expect(find.byKey(const Key('powerSwitch')), findsOneWidget);
    expect(find.text(en.brightness), findsNothing);
    await unmount(tester);
  });

  testWidgets('favorite toggled on the detail page appears in Favorites', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('switch.coffee_machine'));
    await tapKey(tester, 'favoriteToggle');
    await settle(tester, 2);

    await goTo(tester, AppRoutes.favorites);
    expect(find.text('Aparat za kafu'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('unlocking requires confirmation', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('lock.front_door'));
    expect(find.text(en.lockLocked), findsWidgets);

    await tapKey(tester, 'unlockButton');
    await settle(tester, 2);
    expect(
      find.text(en.confirmUnlockTitle('Brava ulazna vrata')),
      findsOneWidget,
    );
    await tester.tap(find.text(en.cancel));
    await settle(tester, 4);
    expect(
      find.text(en.lockLocked),
      findsWidgets,
      reason: 'cancel sends nothing',
    );

    await tapKey(tester, 'unlockButton');
    await settle(tester, 2);
    await tapKey(tester, 'confirmCriticalAction');
    await settle(tester, 5);
    expect(find.text(en.lockUnlocked), findsWidgets);
    await unmount(tester);
  });

  testWidgets('unavailable device shows banner and disabled controls', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('switch.garage_heater'));
    expect(find.text(en.unavailableBanner), findsOneWidget);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('powerSwitch')),
    );
    expect(tile.onChanged, isNull);
    await unmount(tester);
  });

  testWidgets('climate +/- changes the target after a short pause', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('climate.living_room'));
    expect(find.text('23°'), findsOneWidget);

    await tapKey(tester, 'increaseTemperature');
    await tapKey(tester, 'increaseTemperature');
    await tester.pump();
    expect(
      find.text('24°'),
      findsOneWidget,
      reason: 'local value while debouncing',
    );
    await settle(tester, 12);
    expect(find.text('24°'), findsOneWidget, reason: 'confirmed by the server');
    expect(find.text(en.hvacCool), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scenes screen activates a scene', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1200));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.scenes);
    expect(find.text(en.automationsTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.activate).first);
    await settle(tester, 4);
    expect(find.text(en.sceneActivated('Filmsko veče')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rooms and room detail group devices by category', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.room('living_room'));
    expect(find.text(en.groupLights), findsOneWidget);
    expect(find.text(en.groupClimate), findsOneWidget);
    expect(find.text(en.groupCovers), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('phone layout with 150 % text has no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, signedIn: true, size: const Size(360, 780));
    await settle(tester, 10);
    for (final location in [
      AppRoutes.home,
      AppRoutes.room('living_room'),
      AppRoutes.favorites,
      AppRoutes.scenes,
      AppRoutes.device('climate.living_room'),
      AppRoutes.device('light.living_room_ambient'),
      AppRoutes.energy,
      AppRoutes.settings,
      AppRoutes.weather,
      AppRoutes.calendar,
      AppRoutes.addDevice,
      AppRoutes.allDevices,
      AppRoutes.device('media_player.living_room_speaker'),
      AppRoutes.device('alarm_control_panel.home_alarm'),
      AppRoutes.device('fan.bedroom_fan'),
      AppRoutes.device('humidifier.bedroom'),
      AppRoutes.device('vacuum.robot'),
      AppRoutes.device('input_number.night_temperature'),
      AppRoutes.device('sensor.living_room_temperature'),
      AppRoutes.device('camera.driveway'),
    ]) {
      await goTo(tester, location);
      expect(tester.takeException(), isNull, reason: location);
    }
    await unmount(tester);
  });
}
