import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_client.dart';
import 'package:open_smart_home_lite/features/devices/data/local/hue_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/shelly_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';
import 'package:open_smart_home_lite/features/extras/batteries.dart';
import 'package:open_smart_home_lite/features/extras/home_programs.dart';

import '../esphome_fake.dart';
import '../helpers.dart';

SmartHomeDevice sensor(String id, int battery) => SmartHomeDevice(
  id: 'test:$id',
  sourceId: id,
  deviceId: 'test:$id',
  name: 'Senzor $id',
  kind: DeviceKind.temperatureSensor,
  available: true,
  capabilities: const {Capability.currentTemperature},
  state: const DeviceState(raw: '21', currentTemperature: 21),
  metadata: DeviceMetadata(batteryPercent: battery),
);

void main() {
  test('the adapters tell the battery level', () async {
    const bridge = ConfiguredDevice(
      adapter: 'hue',
      id: 'b',
      host: 'hue',
      secured: true,
    );
    final hue = parseHue(bridge, const {}, {
      '5': {
        'type': 'ZLLTemperature',
        'name': 'T',
        'state': {'temperature': 2000},
        'config': {'reachable': true, 'battery': 87},
        'uniqueid': '00:17:88:01:02:03:04:05-02-0402',
      },
    });
    expect(hue.single.metadata.batteryPercent, 87);

    const shelly = ConfiguredDevice(adapter: 'shelly', id: 's', host: 'h');
    final gen2 = parseShellyGen2(shelly, const {}, {
      'temperature:0': {'tC': 20.5},
      'devicepower:0': {
        'battery': {'V': 5.6, 'percent': 64},
      },
    });
    expect(gen2.single.metadata.batteryPercent, 64);
    final gen1 = parseShellyGen1(shelly, const {}, {
      'relays': [
        {'ison': false},
      ],
      'bat': {'value': 12, 'voltage': 2.9},
    });
    expect(gen1.single.metadata.batteryPercent, 12);

    final esp = FakeEsphomeDevice(
      entities: [
        (
          EsphomeMessage.listSensor,
          message(
            (w) => w
              ..string(1, 'baterija')
              ..fixed32(2, 7)
              ..string(3, 'Baterija')
              ..string(6, '%')
              ..string(9, 'battery'),
          ),
        ),
      ],
      states: [
        (
          EsphomeMessage.sensorState,
          message(
            (w) => w
              ..fixed32(1, 7)
              ..float(2, 9),
          ),
        ),
      ],
    );
    final backend = LocalBackend(
      [EsphomeAdapter(connector: esp.connect)],
      home: const LocalHome(
        devices: [ConfiguredDevice(adapter: 'esphome', id: 'e', host: 'h')],
      ),
    )..start();
    addTearDown(backend.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final level = backend.current.devices['esphome:e:sensor_baterija']!;
    expect(
      (level.kind, level.isAuxiliary, level.state.numericValue),
      (DeviceKind.batterySensor, true, 9),
    );
  });

  test('told once while low; again after it was fine', () {
    final told = <String>{};
    BatteryInfo b(String id, int p) => (
      id: id,
      name: id,
      percent: p,
      low: p <= batteryLowPercent,
      sensorId: null,
    );
    expect(newlyLow([b('a', 50), b('b', 10)], told).map((x) => x.id), ['b']);
    expect(newlyLow([b('a', 50), b('b', 9)], told), isEmpty);
    expect(newlyLow([b('a', 50), b('b', 80)], told), isEmpty);
    expect(newlyLow([b('a', 14), b('b', 12)], told).map((x) => x.id), [
      'a',
      'b',
    ]);
  });

  testWidgets('with the reminder on, a battery running low is a notification', (
    tester,
  ) async {
    final adapter = TestAdapter([sensor('a', 50)]);
    final alerts = FakeAlertNotifier();
    final container = ProviderContainer(
      overrides: await testOverrides(adapter: adapter, alerts: alerts),
    );
    container.read(homeProgramsProvider);
    await container.read(batteryReminderProvider.notifier).set(true);

    await tester.runAsync(() async {
      adapter.update(sensor('a', 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(); // the programs listen in the test's own zone
    await tester.runAsync(() async {
      adapter.update(sensor('a', 9));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(alerts.messages.single.$2, contains('Senzor a'));
    expect(container.read(batteriesProvider).single.low, isTrue);
    container.dispose(); // before the test checks for running timers
  });
}
