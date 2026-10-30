import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';

import '../esphome_fake.dart';
import '../helpers.dart';
import 'bridges_test.dart' show hueHost, hueNetwork;
import 'esphome_test.dart' as esphome;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;
import 'lan_adapters_test.dart' show hasRequest, network, plus1pm;

void main() {
  testWidgets('found on the network, added to a room, switched; demo gone', (
    tester,
  ) async {
    final http = FakeLanHttp(network());
    await pumpApp(
      tester,
      size: const Size(800, 1600),
      http: http,
      discovery: FakeLanDiscovery(const [
        LanService(name: 'shellyplus1pm-a8032ab12345', host: plus1pm),
        LanService(name: 'printer', host: '192.168.1.99'),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    expect(container.read(deviceProvider('demo:living_ceiling')), isNotNull);

    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 4);
    expect(find.text('Hodnik'), findsOneWidget);
    expect(find.text('printer'), findsNothing, reason: 'not a Shelly or WLED');

    await tapKey(tester, 'add-shelly:a8032ab12345');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 6);
    expect(find.text(en.addDeviceAdded), findsOneWidget);
    final home = container.read(localHomeProvider);
    expect(home.devices.single.host, plus1pm);
    expect(home.demo, isFalse);
    expect(container.read(deviceProvider('demo:living_ceiling')), isNull);

    const relay = 'shelly:a8032ab12345:switch0';
    expect(container.read(deviceProvider(relay))!.state.isOn, isTrue);
    await goTo(tester, AppRoutes.device(relay));
    await tapKey(tester, 'powerSwitch');
    await settle(tester, 4);
    expect(
      http.requests,
      hasRequest((plus1pm, '/rpc/Switch.Set', {'id': 0, 'on': false})),
    );
    expect(container.read(deviceProvider(relay))!.state.isOn, isFalse);
    await unmount(tester);
  });

  testWidgets('by IP address; an address with no Shelly or WLED is said so', (
    tester,
  ) async {
    await pumpApp(tester, http: FakeLanHttp(network()));
    await goTo(tester, AppRoutes.addDevice);

    await tapKey(tester, 'addDeviceManual');
    await settle(tester, 2);
    await tester.enterText(
      find.byKey(const Key('addDeviceAddress')),
      '192.168.1.99',
    );
    await tapKey(tester, 'addDeviceAddressOk');
    await settle(tester, 3);
    expect(find.text(en.addDeviceNotFound), findsOneWidget);

    await tapKey(tester, 'addDeviceManual');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('addDeviceAddress')), plus1pm);
    await tapKey(tester, 'addDeviceAddressOk');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 10); // the previous message goes first
    expect(find.text(en.addDeviceDone('Hodnik')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a device gets a name and a new room on its screen', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    const lamp = 'demo:bedroom_lamp';
    await goTo(tester, AppRoutes.device(lamp));
    await tapKey(tester, 'editDevice');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('setUpName')), 'Noćna lampa');
    await tester.tap(find.byKey(const Key('setUpRoom')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('setUpRoomNew')).last);
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('roomName')), 'Dečja soba');
    await tapKey(tester, 'roomNameSave');
    await settle(tester, 2);
    await tapKey(tester, 'setUpSave');
    await settle(tester, 3);

    final d = container.read(deviceProvider(lamp))!;
    expect(d.name, 'Noćna lampa');
    final room = container.read(localHomeProvider).rooms.single;
    expect((room.name, d.roomId), ('Dečja soba', room.id));
    await unmount(tester);
  });

  testWidgets('a Shelly with a password: asked when adding, kept secret', (
    tester,
  ) async {
    final net = network();
    net[plus1pm]!['/shelly'] = (_) => {
      'name': 'Hodnik',
      'mac': 'A8032AB12345',
      'gen': 2,
      'app': 'Plus1PM',
      'auth_en': true,
    };
    final http = FakeLanHttp(net, passwords: {plus1pm: 'tajna'});
    final credentials = await pumpApp(
      tester,
      http: http,
      discovery: FakeLanDiscovery(const [
        LanService(name: 'shellyplus1pm-a8032ab12345', host: plus1pm),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 4);
    await tapKey(tester, 'add-shelly:a8032ab12345');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('addDevicePassword')), 'tajna');
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 6);

    final device = container.read(localHomeProvider).devices.single;
    expect(device.secured, isTrue);
    expect(device.toJson().toString(), isNot(contains('tajna')));
    expect(credentials.values['device:shelly:a8032ab12345'], 'tajna');
    expect(
      container.read(deviceProvider('shelly:a8032ab12345:switch0'))?.available,
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('an encrypted ESPHome: found by mDNS, its key asked, connected', (
    tester,
  ) async {
    final fake = FakeEsphomeDevice(
      key: esphome.key,
      mac: 'AA:BB:CC:DD:EE:02',
      entities: esphome.entities,
      states: esphome.states,
    );
    final credentials = await pumpApp(
      tester,
      http: FakeLanHttp(const {}),
      esphome: fake.connect,
      discovery: FakeLanDiscovery(const [
        LanService(
          name: 'kuhinja',
          host: '192.168.1.50',
          port: 6053,
          type: LanService.esphomeType,
          txt: {
            'mac': 'aabbccddee02',
            'friendly_name': 'Kuhinja',
            'api_encryption': 'Noise_NNpsk0_25519_ChaChaPoly_SHA256',
          },
        ),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 4);
    expect(find.text('Kuhinja'), findsOneWidget);

    // A wrong key first.
    await tapKey(tester, 'add-esphome:aabbccddee02');
    await settle(tester, 3);
    expect(find.text(en.deviceKeyHint), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('addDevicePassword')),
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    );
    await tapKey(tester, 'addDeviceConfirm');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester, 6);
    expect(find.text(en.deviceKeyWrong), findsOneWidget);
    expect(container.read(localHomeProvider).devices, isEmpty);

    await tapKey(tester, 'add-esphome:aabbccddee02');
    await settle(tester, 3);
    await tester.enterText(
      find.byKey(const Key('addDevicePassword')),
      esphome.key,
    );
    await tapKey(tester, 'addDeviceConfirm');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester, 10);
    expect(credentials.values['device:esphome:aabbccddee02'], esphome.key);
    expect(container.read(localHomeProvider).devices.single.secured, isTrue);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester, 4);
    expect(
      container
          .read(deviceProvider('esphome:aabbccddee02:switch_relej'))
          ?.state
          .isOn,
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('a Hue bridge: paired with its button, its lights come', (
    tester,
  ) async {
    var pressed = false;
    final credentials = await pumpApp(
      tester,
      http: FakeLanHttp(hueNetwork(pressed: () => pressed)),
      discovery: FakeLanDiscovery(const [
        LanService(name: 'Hue most', host: hueHost, type: LanService.hueType),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 4);
    expect(find.text('Hue most'), findsOneWidget);

    await tapKey(tester, 'add-hue:ecb5fafffe0a1b2c');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 3);
    expect(find.text(en.hueLinkBody), findsOneWidget);
    await settle(tester, 25); // asked, not pressed yet
    expect(container.read(localHomeProvider).devices, isEmpty);

    pressed = true;
    await settle(tester, 25);
    expect(find.byKey(const Key('deviceLink')), findsNothing);
    expect(credentials.values['device:hue:ecb5fafffe0a1b2c'], 'user1');
    await settle(tester, 4);
    expect(
      container.read(deviceProvider('hue:ecb5fafffe0a1b2c:light1'))?.name,
      'Lampa',
    );
    await unmount(tester);
  });
}
