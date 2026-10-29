import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/device_sensors/device_sensors.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeAlertNotifier, FakeDeviceBattery;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  const battery = BatteryReading(
    level: 55,
    state: 'discharging',
    charger: 'none',
  );

  test('register once with names and classes, then states only', () {
    final full = sensorPayloads(en, battery: battery, kiosk: true, full: true);
    final level = full.firstWhere((s) => s['unique_id'] == 'battery_level');
    expect(level['device_class'], 'battery');
    expect(level['unit_of_measurement'], '%');
    expect(level['name'], en.deviceSensorBattery);
    final updates = sensorPayloads(en, battery: battery, kiosk: true);
    expect(updates.every((s) => !s.containsKey('name')), isTrue);
    expect(
      updates.firstWhere((s) => s['unique_id'] == 'is_charging')['state'],
      false,
    );
    expect(updates.firstWhere((s) => s['unique_id'] == 'kiosk')['state'], true);
    expect(
      sensorPayloads(
        en,
        battery: null,
        kiosk: false,
      ).map((s) => s['unique_id']),
      ['kiosk'],
      reason: 'no battery reading, no battery sensors',
    );
  });

  test('smart charging automation: on below 40, off above 80', () {
    final config = chargeAutomation(
      alias: 'x',
      battery: 'sensor.tab_battery',
      plug: 'switch.charger',
    );
    final triggers = config['triggers']! as List;
    expect(triggers, hasLength(2));
    expect((triggers[0] as Map)['below'], 40);
    expect((triggers[1] as Map)['above'], 80);
    final choose =
        ((config['actions']! as List).single as Map)['choose']! as List;
    String action(int i) =>
        (((choose[i] as Map)['sequence']! as List).single as Map)['action']!
            as String;
    expect(action(0), 'switch.turn_on');
    expect(action(1), 'switch.turn_off');
  });

  testWidgets('battery and kiosk become sensors; smart charging automation', (
    tester,
  ) async {
    final fake = FakeDeviceBattery();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      alerts: FakeAlertNotifier(),
      battery: fake,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('notifications'));
    await tapKey(tester, 'haPushTile');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('haPushName')), 'Zidni tablet');
    await tester.tap(find.byKey(const Key('haPushRegister')));
    await settle(tester, 8);
    final webhook = server.mobileApps.keys.single;

    fake.emit(battery);
    await tapKey(tester, 'deviceSensorsSwitch');
    await settle(tester, 8);
    final ids = server.mobileAppSensorIds[webhook]!;
    expect(ids.keys, containsAll(['battery_level', 'is_charging', 'kiosk']));
    expect(server.stateForTest(ids['battery_level']!), '55');
    expect(server.stateForTest(ids['is_charging']!), 'off');

    fake.emit(
      const BatteryReading(level: 61, state: 'charging', charger: 'ac'),
    );
    await settle(tester, 6);
    expect(server.stateForTest(ids['battery_level']!), '61');
    expect(server.stateForTest(ids['is_charging']!), 'on');

    // The battery sensor is now a device in the home: offer smart charging.
    await settle(tester, 6);
    await tapKey(tester, 'smartChargePlug');
    await settle(tester, 3);
    await tester.tap(find.text('Utičnica TV').last);
    await settle(tester, 3);
    await tapKey(tester, 'smartChargeCreate');
    await settle(tester, 6);
    final automation = server.automations['osh_charge_zidni_tablet']!;
    final trigger = (automation['triggers']! as List).first as Map;
    expect(trigger['entity_id'], ids['battery_level']);
    await unmount(tester);
  });
}
