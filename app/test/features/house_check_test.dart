import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/house_check/house_check.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mappers/ha_device_mapper.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_models.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_registry.dart';
import 'package:open_smart_home_lite/app/app.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  const mapper = HaDeviceMapper();
  SmartHomeDevice map(
    String id,
    String state, [
    Map<String, Object?> attributes = const {},
  ]) => mapper.map(
    HaEntityState(entityId: id, state: state, attributes: attributes),
    HaRegistries.empty,
  );

  final devices = [
    map('light.kitchen', 'on'),
    map('light.hall', 'off'),
    map('lock.front', 'unlocked', {'supported_features': 0}),
    map('binary_sensor.window', 'on', {'device_class': 'window'}),
    map('cover.garage', 'open', {
      'device_class': 'garage',
      'supported_features': 3,
    }),
    map('climate.living', 'heat', {
      'hvac_modes': ['off', 'heat'],
      'supported_features': 128 | 256,
    }),
    map('media_player.tv', 'playing', {'supported_features': 256}),
    map('light.offline', 'unavailable'),
  ];

  test('leaving: security first, lights last; fixes where possible', () {
    final items = houseCheck(devices, HouseCheckMode.leaving);
    expect(
      [for (final i in items) i.device.id],
      [
        'binary_sensor.window',
        'cover.garage',
        'lock.front',
        'climate.living',
        'media_player.tv',
        'light.kitchen',
      ],
    );
    final fixes = {for (final i in items) i.device.id: i.fix};
    expect(fixes['binary_sensor.window'], isNull, reason: 'cannot close it');
    expect(fixes['cover.garage'], isA<CloseCover>());
    expect(fixes['lock.front'], isA<LockDevice>());
    expect(fixes['light.kitchen'], isA<TurnOff>());
  });

  test('night keeps the heating running', () {
    final items = houseCheck(devices, HouseCheckMode.night);
    expect(items.map((i) => i.device.id), isNot(contains('climate.living')));
    expect(items.map((i) => i.device.id), contains('lock.front'));
  });

  test('the mode follows the time of day', () {
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 9)),
      HouseCheckMode.leaving,
    );
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 22)),
      HouseCheckMode.night,
    );
    expect(
      HouseCheckMode.forTime(DateTime(2026, 1, 1, 2)),
      HouseCheckMode.night,
    );
  });

  testWidgets('fix everything the app can before leaving', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
    await settle(tester, 10);
    await tapKey(tester, 'openHouseCheck');
    await settle(tester, 4);
    await goTo(tester, AppRoutes.houseCheckFor('leaving'));
    await settle(tester, 4);

    for (final id in [
      'light.living_room_main',
      'light.living_room_ambient',
      'climate.living_room',
      'media_player.living_room_speaker',
      'humidifier.bedroom',
      'alarm_control_panel.home_alarm',
    ]) {
      expect(
        find.byKey(ValueKey('houseCheck-$id')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(
      find.byKey(
        const ValueKey('houseCheckOpen-alarm_control_panel.home_alarm'),
      ),
      findsOneWidget,
      reason: 'the alarm needs its own screen (code)',
    );

    await tapKey(tester, 'houseCheckFixAll');
    await settle(tester, 20);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    String state(String id) =>
        server.states.firstWhere((s) => s['entity_id'] == id)['state']!
            as String;
    expect(state('light.living_room_main'), 'off');
    expect(state('light.living_room_ambient'), 'off');
    expect(state('climate.living_room'), 'off');
    expect(state('media_player.living_room_speaker'), 'off');
    expect(state('humidifier.bedroom'), 'off');
    expect(find.byKey(const Key('houseCheckFixAll')), findsNothing);
    expect(
      find.byKey(const ValueKey('houseCheck-alarm_control_panel.home_alarm')),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
