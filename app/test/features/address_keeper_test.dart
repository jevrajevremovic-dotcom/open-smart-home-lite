import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/add_device/application/address_keeper.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';

import '../helpers.dart';
import 'lan_adapters_test.dart' show network, plus1pm, wled;

void main() {
  test('a device the router gave a new address is followed', () async {
    const moved = '192.168.1.77';
    final net = network();
    final container = ProviderContainer(
      overrides: await testOverrides(
        http: FakeLanHttp({
          ...net,
          moved: net[plus1pm]!, // the same Shelly, now here
        }),
        discovery: FakeLanDiscovery(const [
          LanService(name: 'shellyplus1pm-a8032ab12345', host: moved),
          LanService(name: 'wled-traka', host: wled),
        ]),
        preferences: {
          'localHome': jsonEncode(
            const LocalHome(
              demo: false,
              devices: [
                ConfiguredDevice(
                  adapter: 'shelly',
                  id: 'a8032ab12345',
                  host: plus1pm,
                ),
              ],
            ).toJson(),
          ),
        },
      ),
    );
    addTearDown(container.dispose);

    container.read(addressKeeperProvider).check();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final home = container.read(localHomeProvider);
    expect(home.devices.single.host, moved);
    expect(home.devices, hasLength(1), reason: 'the WLED was not added');
  });
}
