import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/zigbee_pairing.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../integrations/home_assistant_api_test.dart' show address;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

SmartHomeDevice device(String id, {String? manufacturer}) => SmartHomeDevice(
  id: id,
  sourceId: id,
  name: id,
  kind: DeviceKind.sensor,
  protocol: DeviceProtocol.unknown,
  manufacturer: manufacturer,
  available: true,
  capabilities: const {},
  state: const DeviceState(raw: 'on'),
);

MockHomeAssistantServer serverOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
        .read(mockHomeAssistantServerProvider);

void main() {
  test('Zigbee backend detection', () {
    expect(
      detectZigbeeBackends({
        'zha': {'permit'},
      }, const []),
      {ZigbeeBackend.zha},
    );
    expect(
      detectZigbeeBackends(
        {
          'mqtt': {'publish'},
        },
        [device('sensor.x', manufacturer: 'Zigbee2MQTT')],
      ),
      {ZigbeeBackend.zigbee2mqtt},
    );
    expect(
      detectZigbeeBackends(
        {
          'mqtt': {'publish'},
        },
        [device('sensor.x')],
      ),
      isEmpty,
      reason: 'MQTT alone does not mean Zigbee2MQTT',
    );
  });

  test('permit join: zha.permit and Zigbee2MQTT bridge request', () async {
    final server = MockHomeAssistantServer();
    final api = MockHomeAssistantApi(
      address: address,
      server: server,
      readToken: () async => 'token',
    );
    final pairing = ZigbeePairing(api);
    await pairing.permit(ZigbeeBackend.zha, const Duration(minutes: 10));
    expect(server.permitJoinSeconds, 254, reason: 'capped at 254 s');
    await pairing.permit(ZigbeeBackend.zha, Duration.zero);
    expect(server.permitJoinSeconds, 0);

    await pairing.permit(
      ZigbeeBackend.zigbee2mqtt,
      const Duration(seconds: 120),
    );
    final (topic, payload) = server.lastMqttPublish!;
    expect(topic, 'zigbee2mqtt/bridge/request/permit_join');
    expect(jsonDecode(payload), {'value': true, 'time': 120});
    expect(
      () => ZigbeePairing(
        api,
        z2mBaseTopic: 'a/#',
      ).permit(ZigbeeBackend.zigbee2mqtt, Duration.zero),
      throwsArgumentError,
    );
  });

  testWidgets(
    'add a Zigbee device: pairing, new devices, name and room; closes on exit',
    (tester) async {
      await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
      await settle(tester, 10);
      final server = serverOf(tester);
      await goTo(tester, AppRoutes.settingsSection('server'));
      await tapKey(tester, 'settingsAddDevice');
      await settle(tester, 4);
      expect(find.text(en.addDeviceTitle), findsWidgets);
      expect(find.textContaining(en.zigbeeViaZha), findsOneWidget);
      await tapKey(tester, 'addZigbee');
      await settle(tester, 2);

      await tapKey(tester, 'pairingStart');
      await settle(tester, 2);
      expect(server.permitJoinSeconds, 180);
      expect(find.text(en.pairingWaiting), findsOneWidget);
      expect(find.byKey(const Key('pairingStop')), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await settle(tester, 6);
      expect(
        find.byKey(const ValueKey('newDevice-d_new_door')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await settle(tester, 6);
      expect(
        find.byKey(const ValueKey('newDevice-d_new_bulb')),
        findsOneWidget,
      );

      await tapKey(tester, 'setUp-d_new_door');
      await settle(tester, 2);
      await tester.enterText(
        find.byKey(const Key('setUpName')),
        'Ulazna vrata senzor',
      );
      await tester.tap(find.byKey(const Key('setUpRoom')));
      await settle(tester, 2);
      await tester.tap(find.text('Hodnik').last);
      await settle(tester, 2);
      await tapKey(tester, 'setUpSave');
      await settle(tester, 8);
      expect(find.text(en.setUpSaved), findsOneWidget);
      expect(find.text('Ulazna vrata senzor'), findsOneWidget);
      final entry = server.registries.devices.firstWhere(
        (d) => d['id'] == 'd_new_door',
      );
      expect(entry['area_id'], 'hallway');

      Navigator.of(tester.element(find.byKey(const Key('pairingStart')))).pop();
      await settle(tester, 10);
      expect(find.byKey(const Key('pairingStart')), findsNothing);
      expect(server.permitJoinSeconds, 0, reason: 'closed when leaving');
      await unmount(tester);
    },
  );
}
