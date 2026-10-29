import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/add_device/data/device_probe.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/esphome_client.dart';
import 'package:open_smart_home_lite/features/devices/data/local/esphome/noise.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../esphome_fake.dart';
import '../helpers.dart';

const key = 'px7tsbK3C7bpXHr2OevEV2ZMg/FrNBw2+O2pNPbedtA=';
const host = '192.168.1.50';

final entities = [
  (
    EsphomeMessage.listSwitch,
    message(
      (w) => w
        ..string(1, 'relej')
        ..fixed32(2, 1001)
        ..string(3, 'Relej'),
    ),
  ),
  (
    EsphomeMessage.listLight,
    message(
      (w) => w
        ..string(1, 'svetlo')
        ..fixed32(2, 1002)
        ..string(3, 'Svetlo')
        ..uint(12, 35) // RGB
        ..uint(12, 11) // colour temperature
        ..float(9, 153)
        ..float(10, 500),
    ),
  ),
  (
    EsphomeMessage.listSensor,
    message(
      (w) => w
        ..string(1, 'temperatura')
        ..fixed32(2, 1003)
        ..string(3, 'Temperatura')
        ..string(6, '°C')
        ..string(9, 'temperature'),
    ),
  ),
  (
    EsphomeMessage.listSensor,
    message(
      (w) => w
        ..string(1, 'wifi_signal')
        ..fixed32(2, 1004)
        ..string(3, 'WiFi signal')
        ..string(6, 'dBm')
        ..uint(13, 2), // diagnostic
    ),
  ),
  (
    EsphomeMessage.listBinarySensor,
    message(
      (w) => w
        ..string(1, 'vrata')
        ..fixed32(2, 1005)
        ..string(3, 'Vrata')
        ..string(5, 'door'),
    ),
  ),
  (
    EsphomeMessage.listCover,
    message(
      (w) => w
        ..string(1, 'roletna')
        ..fixed32(2, 1006)
        ..string(3, 'Roletna')
        ..boolean(6, true)
        ..boolean(12, true),
    ),
  ),
  (
    EsphomeMessage.listButton,
    message(
      (w) => w
        ..string(1, 'restart')
        ..fixed32(2, 1007)
        ..string(3, 'Restart')
        ..uint(7, 1), // config
    ),
  ),
  (
    EsphomeMessage.listSwitch,
    message(
      (w) => w
        ..string(1, 'skriveno')
        ..fixed32(2, 1008)
        ..string(3, 'Skriveno')
        ..boolean(7, true), // disabled by default
    ),
  ),
];

final states = [
  (
    EsphomeMessage.switchState,
    message(
      (w) => w
        ..fixed32(1, 1001)
        ..boolean(2, true),
    ),
  ),
  (
    EsphomeMessage.lightState,
    message(
      (w) => w
        ..fixed32(1, 1002)
        ..boolean(2, true)
        ..float(3, 0.5)
        ..float(4, 1)
        ..float(5, 0.5)
        ..uint(11, 35),
    ),
  ),
  (
    EsphomeMessage.sensorState,
    message(
      (w) => w
        ..fixed32(1, 1003)
        ..float(2, 22.5),
    ),
  ),
  (
    EsphomeMessage.binarySensorState,
    message(
      (w) => w
        ..fixed32(1, 1005)
        ..boolean(2, true),
    ),
  ),
  (
    EsphomeMessage.coverState,
    message(
      (w) => w
        ..fixed32(1, 1006)
        ..float(3, 0.4),
    ),
  ),
];

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('Noise NNpsk0: both sides agree and talk', () async {
    final psk = base64.decode(key);
    final app = NoiseHandshake.initiator(psk);
    final device = NoiseHandshake.responder(psk);
    final answer = await device.readFirstAndAnswer(await app.writeFirst());
    await app.readAnswer(answer);
    final (appSend, appReceive) = app.split();
    final (deviceSend, deviceReceive) = device.split();
    for (final text in ['jedan', 'dva', 'tri']) {
      final c = await appSend.encrypt(Uint8List.fromList(utf8.encode(text)));
      expect(utf8.decode(await deviceReceive.decrypt(c)), text);
    }
    final back = await deviceSend.encrypt(Uint8List.fromList([1, 2, 3]));
    expect(await appReceive.decrypt(back), [1, 2, 3]);

    // Another key: the answer cannot be read.
    final stranger = NoiseHandshake.responder(Uint8List(32));
    await expectLater(
      stranger.readFirstAndAnswer(
        await NoiseHandshake.initiator(psk).writeFirst(),
      ),
      throwsA(isA<NoiseAuthenticationError>()),
    );
  });

  for (final encrypted in [false, true]) {
    group(encrypted ? 'encrypted' : 'plaintext', () {
      late FakeEsphomeDevice fake;
      late LocalBackend backend;

      setUp(() {
        fake = FakeEsphomeDevice(
          key: encrypted ? key : null,
          entities: entities,
          states: states,
        );
        backend = LocalBackend(
          [
            EsphomeAdapter(
              connector: fake.connect,
              keys: (_) async => encrypted ? key : null,
            ),
          ],
          home: LocalHome(
            demo: false,
            devices: [
              ConfiguredDevice(
                adapter: 'esphome',
                id: 'aabbccddee01',
                host: host,
                secured: encrypted,
              ),
            ],
          ),
        )..start();
      });
      tearDown(() => backend.dispose());

      test('entities become devices, with their state', () async {
        await settle();
        final d = backend.current.devices;
        const p = 'esphome:aabbccddee01';
        final relay = d['$p:switch_relej']!;
        expect(
          (relay.name, relay.state.isOn, relay.available),
          ('Relej', true, true),
        );
        expect(relay.protocol, DeviceProtocol.esphome);
        final light = d['$p:light_svetlo']!;
        expect(light.kind, DeviceKind.rgbLight);
        expect(
          light.capabilities,
          containsAll({
            Capability.brightness,
            Capability.rgb,
            Capability.colorTemperature,
          }),
        );
        expect(light.state.brightnessPercent, 50);
        expect(light.state.rgb, const RgbColor(255, 128, 0));
        expect(light.limits.minColorTemperatureKelvin, 2000);
        expect(light.limits.maxColorTemperatureKelvin, 6536);
        final t = d['$p:sensor_temperatura']!;
        expect(
          (t.kind, t.state.currentTemperature, t.state.unit),
          (DeviceKind.temperatureSensor, 22.5, '°C'),
        );
        expect(d['$p:sensor_wifi_signal']!.isAuxiliary, isTrue);
        expect(d['$p:button_restart']!.isAuxiliary, isTrue);
        final door = d['$p:binary_sensor_vrata']!;
        expect(
          (door.kind, door.state.isActive),
          (DeviceKind.contactSensor, true),
        );
        final cover = d['$p:cover_roletna']!;
        expect(
          (cover.state.position, cover.supports(Capability.stop)),
          (40, true),
        );
        expect(d.containsKey('$p:switch_skriveno'), isFalse);
        expect(fake.connections, 1);
      });

      test('commands go as API requests; changes come pushed', () async {
        await settle();
        SmartHomeDevice dev(String id) =>
            backend.current.devices['esphome:aabbccddee01:$id']!;

        await backend.send(dev('switch_relej'), const TurnOff());
        await backend.send(dev('light_svetlo'), const SetBrightness(30));
        await backend.send(dev('cover_roletna'), const SetCoverPosition(70));
        await backend.send(dev('button_restart'), const Activate());
        await settle();
        final [sw, light, cover, button] = fake.commands;
        expect(
          (sw.$1, sw.$2.fixed32(1), sw.$2.boolean(2)),
          (EsphomeMessage.switchCommand, 1001, false),
        );
        expect(light.$1, EsphomeMessage.lightCommand);
        expect((light.$2.boolean(3), light.$2.boolean(4)), (true, true));
        expect(light.$2.float(5), closeTo(0.3, 0.001));
        expect(cover.$1, EsphomeMessage.coverCommand);
        expect(cover.$2.boolean(4), isTrue);
        expect(cover.$2.float(5), closeTo(0.7, 0.001));
        expect(
          (button.$1, button.$2.fixed32(1)),
          (EsphomeMessage.buttonCommand, 1007),
        );

        fake.push(
          EsphomeMessage.switchState,
          message((w) => w..fixed32(1, 1001)),
        );
        await settle();
        expect(dev('switch_relej').state.isOn, isFalse);
      });

      test('a device that goes away is unavailable, then reconnects', () async {
        await settle();
        fake.drop();
        await settle();
        final relay =
            backend.current.devices['esphome:aabbccddee01:switch_relej']!;
        expect(relay.available, isFalse);
        expect(relay.state.isOn, isTrue, reason: 'last known state');

        await backend.refresh(); // instead of waiting for the retry
        await settle();
        expect(
          backend
              .current
              .devices['esphome:aabbccddee01:switch_relej']!
              .available,
          isTrue,
        );
        expect(fake.connections, 2);
      });
    });
  }

  group('probe', () {
    final plain = FakeEsphomeDevice();
    final locked = FakeEsphomeDevice(key: key, mac: 'AA:BB:CC:DD:EE:02');
    DeviceProbe probeOf(FakeEsphomeDevice d) =>
        DeviceProbe(FakeLanHttp(const {}), d.connect);

    test('by address: plaintext, needing a key, a wrong key', () async {
      final p = (await probeOf(plain).probeAddress(host))!;
      expect(
        (p.brand, p.title, p.device.key, p.needsKey),
        ('ESPHome', 'Kuhinja', 'esphome:aabbccddee01', false),
      );

      final asks = (await probeOf(locked).probeAddress(host))!;
      expect((asks.needsKey, asks.device.id), (true, ''));
      final ok = (await probeOf(locked).probeEsphome(host, key: key))!;
      expect(ok.device.key, 'esphome:aabbccddee02');

      await expectLater(
        probeOf(locked).probeEsphome(host, key: base64.encode(Uint8List(32))),
        throwsA(isA<EsphomeKeyError>()),
      );
      await expectLater(
        probeOf(locked).probeEsphome(host, key: 'kratko'),
        throwsA(isA<EsphomeKeyError>()),
      );
      await expectLater(
        probeOf(plain).probeEsphome(host, key: key),
        throwsA(
          isA<EsphomeKeyError>().having(
            (e) => e.reason,
            'reason',
            'notEncrypted',
          ),
        ),
      );
    });

    test('by its mDNS announcement, without connecting', () async {
      final unseen = FakeEsphomeDevice(key: key);
      final p = (await probeOf(unseen).probeService(
        const LanService(
          name: 'kuhinja',
          host: host,
          port: 6053,
          type: '_esphomelib._tcp',
          txt: {
            'mac': 'aabbccddee02',
            'friendly_name': 'Kuhinja',
            'api_encryption': 'Noise_NNpsk0_25519_ChaChaPoly_SHA256',
            'board': 'esp32dev',
          },
        ),
      ))!;
      expect(
        (p.title, p.device.key, p.needsKey, p.device.model),
        ('Kuhinja', 'esphome:aabbccddee02', true, 'esp32dev'),
      );
      expect(unseen.connections, 0);
    });
  });
}
