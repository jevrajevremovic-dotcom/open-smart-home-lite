import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/add_device/data/device_probe.dart';
import 'package:open_smart_home_lite/features/devices/data/local/hue_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/kasa_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/yeelight_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/home_snapshot.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';
import 'lan_adapters_test.dart' show hasRequest;

const hueHost = '192.168.1.60';

/// A Hue bridge: its button is pressed once [press] is set.
Map<String, Map<String, Object? Function(Map<String, Object?>)>> hueNetwork({
  bool Function()? pressed,
}) => {
  hueHost: {
    '/api/config': (_) => {
      'name': 'Hue most',
      'bridgeid': 'ECB5FAFFFE0A1B2C',
      'modelid': 'BSB002',
      'mac': 'ec:b5:fa:0a:1b:2c',
    },
    '/api': (_) => (pressed?.call() ?? false)
        ? [
            {
              'success': {'username': 'user1'},
            },
          ]
        : [
            {
              'error': {'type': 101, 'description': 'link button not pressed'},
            },
          ],
    '/api/user1/lights': (_) => {
      '1': {
        'state': {
          'on': true,
          'bri': 254,
          'ct': 366,
          'xy': [0.4573, 0.41],
          'colormode': 'ct',
          'reachable': true,
        },
        'type': 'Extended color light',
        'name': 'Lampa',
        'modelid': 'LCT015',
        'uniqueid': '00:17:88:01:00:aa:bb:cc-0b',
        'capabilities': {
          'control': {
            'ct': {'min': 153, 'max': 500},
          },
        },
      },
      '2': {
        'state': {'on': false, 'bri': 100, 'reachable': false},
        'type': 'Dimmable light',
        'name': 'Hodnik',
        'uniqueid': '00:17:88:01:00:aa:bb:01-0b',
      },
    },
    '/api/user1/sensors': (_) => {
      '1': {'type': 'Daylight', 'name': 'Daylight'},
      '5': {
        'type': 'ZLLTemperature',
        'name': 'Senzor temperatura',
        'state': {'temperature': 2150},
        'config': {'reachable': true},
        'uniqueid': '00:17:88:01:02:03:04:05-02-0402',
      },
      '6': {
        'type': 'ZLLPresence',
        'name': 'Senzor',
        'state': {'presence': true},
        'config': {'reachable': true},
        'uniqueid': '00:17:88:01:02:03:04:05-02-0406',
      },
    },
    'PUT /api/user1/lights/1/state': (_) => [
      {
        'success': {'/lights/1/state/on': true},
      },
    ],
    '/api/stari/lights': (_) => [
      {
        'error': {'type': 1, 'description': 'unauthorized user'},
      },
    ],
    '/api/stari/sensors': (_) => <String, Object?>{},
  },
};

Future<HomeSnapshot> settled(LocalBackend b) async {
  await b.refresh();
  await Future<void>.delayed(Duration.zero);
  return b.current;
}

void main() {
  group('Hue', () {
    late FakeLanHttp http;
    late LocalBackend backend;
    const bridge = ConfiguredDevice(
      adapter: 'hue',
      id: 'ecb5fafffe0a1b2c',
      host: hueHost,
      secured: true,
    );
    LocalBackend withUser(String user) => LocalBackend([
      HueAdapter(
        http,
        users: (_) async => user,
        pollEvery: const Duration(hours: 1),
      ),
    ], home: const LocalHome(devices: [bridge]))..start();

    setUp(() {
      http = FakeLanHttp(hueNetwork());
      backend = withUser('user1');
    });
    tearDown(() => backend.dispose());

    test(
      'lights and sensors of the bridge, each a device of its own',
      () async {
        final d = (await settled(backend)).devices;
        final lamp = d['hue:ecb5fafffe0a1b2c:light1']!;
        expect(lamp.kind, DeviceKind.rgbLight);
        expect(lamp.protocol, DeviceProtocol.zigbee);
        expect(
          lamp.capabilities,
          containsAll({
            Capability.brightness,
            Capability.colorTemperature,
            Capability.rgb,
          }),
        );
        expect(lamp.state.brightnessPercent, 100);
        expect(lamp.state.colorTemperatureKelvin, 2732);
        expect(lamp.state.rgb, isNull, reason: 'in colour-temperature mode');
        expect(lamp.limits.minColorTemperatureKelvin, 2000);
        expect(
          lamp.deviceId,
          'hue:ecb5fafffe0a1b2c:00178801 00aabbcc'.replaceAll(' ', ''),
        );
        final hall = d['hue:ecb5fafffe0a1b2c:light2']!;
        expect((hall.kind, hall.available), (DeviceKind.dimmableLight, false));
        final t = d['hue:ecb5fafffe0a1b2c:sensor5']!;
        expect(t.state.currentTemperature, 21.5);
        final motion = d['hue:ecb5fafffe0a1b2c:sensor6']!;
        expect(
          (motion.kind, motion.state.isActive),
          (DeviceKind.motionSensor, true),
        );
        expect(t.deviceId, motion.deviceId, reason: 'one physical sensor');
        expect(d.containsKey('hue:ecb5fafffe0a1b2c:sensor1'), isFalse);
      },
    );

    test('commands are PUT to the light\'s state', () async {
      final lamp = (await settled(backend))
          .devices['hue:ecb5fafffe0a1b2c:light1']!;
      await backend.send(lamp, const SetRgbColor(RgbColor(255, 0, 0)));
      await backend.send(lamp, const SetBrightness(50));
      await backend.send(lamp, const SetColorTemperature(4000));
      expect(
        http.requests,
        hasRequest((
          hueHost,
          'PUT /api/user1/lights/1/state',
          {
            'body': {
              'on': true,
              'xy': [0.7006, 0.2993],
            },
          },
        )),
      );
      expect(
        http.requests,
        hasRequest((
          hueHost,
          'PUT /api/user1/lights/1/state',
          {
            'body': {'on': true, 'bri': 127},
          },
        )),
      );
      expect(
        http.requests,
        hasRequest((
          hueHost,
          'PUT /api/user1/lights/1/state',
          {
            'body': {'on': true, 'ct': 250},
          },
        )),
      );
    });

    test('a user name the bridge forgot: unavailable', () async {
      final stale = withUser('stari');
      addTearDown(stale.dispose);
      final d = (await settled(stale)).devices;
      expect(d['hue:ecb5fafffe0a1b2c:device']!.available, isFalse);
    });

    test('pairing waits for the button', () async {
      var pressed = false;
      final net = FakeLanHttp(hueNetwork(pressed: () => pressed));
      expect(await hueLink(net, hueHost), isNull);
      pressed = true;
      expect(await hueLink(net, hueHost), 'user1');
      final p = (await DeviceProbe(net, noEsphome).probe(hueHost))!;
      expect(
        (p.brand, p.needsLink, p.device.key),
        ('Hue', true, 'hue:ecb5fafffe0a1b2c'),
      );
    });

    test('colours: rgb → xy → rgb comes back close', () {
      for (final c in const [
        RgbColor(255, 0, 0),
        RgbColor(0, 255, 0),
        RgbColor(0, 0, 255),
        RgbColor(255, 160, 0),
      ]) {
        final [x, y] = rgbToXy(c);
        final back = xyToRgb(x, y);
        for (final (a, b) in [
          (c.red, back.red),
          (c.green, back.green),
          (c.blue, back.blue),
        ]) {
          expect((a - b).abs(), lessThanOrEqualTo(3), reason: '$c → $back');
        }
      }
    });
  });

  group('Yeelight', () {
    test('a search answer', () {
      final bulb = parseYeelightAnswer(
        'HTTP/1.1 200 OK\r\n'
        'Cache-Control: max-age=3600\r\n'
        'Location: yeelight://192.168.1.70:55443\r\n'
        'id: 0x000000000015243f\r\n'
        'model: color\r\n'
        'support: get_prop set_power toggle set_bright set_ct_abx set_rgb\r\n'
        'name: Stona\r\n',
      )!;
      expect(
        (bulb.id, bulb.host, bulb.model, bulb.name),
        ('000000000015243f', '192.168.1.70', 'color', 'Stona'),
      );
      expect(parseYeelightAnswer('NOTIFY * HTTP/1.1\r\n'), isNull);
    });

    test('state and commands', () async {
      final bulb = FakeYeelight(
        answer: (host, method, params) => method == 'get_prop'
            ? ['on', '80', '4000', '16711680', '1', 'Stona']
            : ['ok'],
      );
      final backend = LocalBackend(
        [YeelightAdapter(bulb, pollEvery: const Duration(hours: 1))],
        home: const LocalHome(
          devices: [
            ConfiguredDevice(
              adapter: 'yeelight',
              id: '000000000015243f',
              host: '192.168.1.70',
              model: 'color',
            ),
          ],
        ),
      )..start();
      addTearDown(backend.dispose);
      final d = (await settled(backend))
          .devices['yeelight:000000000015243f:light']!;
      expect(
        (d.name, d.kind, d.state.brightnessPercent),
        ('Stona', DeviceKind.rgbLight, 80),
      );
      expect(d.state.rgb, const RgbColor(255, 0, 0));

      await backend.send(d, const SetRgbColor(RgbColor(0, 0, 255)));
      await backend.send(d, const SetBrightness(0));
      expect(bulb.calls.where((c) => c.$2 != 'get_prop').map((c) => c.$2), [
        'set_rgb',
        'set_power',
      ]);
      expect(bulb.calls.firstWhere((c) => c.$2 == 'set_rgb').$3, [
        255,
        'smooth',
        300,
      ]);
    });
  });

  group('Kasa', () {
    // The last command (each is followed by reading the state again).
    Map<String, Object?> sent(FakeKasa kasa) =>
        kasa.requests.lastWhere((r) => !r.$2.containsKey('emeter')).$2;

    test('the autokey XOR, both ways', () {
      const json = '{"system":{"get_sysinfo":{}}}';
      final data = kasaEncrypt(json);
      expect(data.take(3), [0xd0, 0xf2, 0x81]);
      expect(kasaDecrypt(data), json);
    });

    Map<String, Object?> sysinfo(Map<String, Object?> info) => {
      'system': {'get_sysinfo': info},
    };

    Future<(LocalBackend, FakeKasa)> home(Map<String, Object?> info) async {
      final kasa = FakeKasa(
        answer: (host, request) =>
            request.containsKey('system') &&
                request['system'] is Map &&
                (request['system']! as Map).containsKey('get_sysinfo')
            ? {
                ...sysinfo(info),
                'emeter': {
                  'get_realtime': {'power_mw': 23500, 'err_code': 0},
                },
              }
            : {
                'system': {
                  'set_relay_state': {'err_code': 0},
                },
              },
      );
      final backend = LocalBackend(
        [KasaAdapter(kasa, pollEvery: const Duration(hours: 1))],
        home: LocalHome(
          devices: [
            ConfiguredDevice(
              adapter: 'kasa',
              id: kasaMac(info)!,
              host: '192.168.1.80',
            ),
          ],
        ),
      )..start();
      await settled(backend);
      return (backend, kasa);
    }

    test('a plug with power, switched', () async {
      final (backend, kasa) = await home({
        'alias': 'Grejalica',
        'model': 'HS110(EU)',
        'mac': '50:C7:BF:00:11:22',
        'relay_state': 0,
      });
      addTearDown(backend.dispose);
      final d = backend.current.devices;
      final plug = d['kasa:50c7bf001122:relay']!;
      expect(
        (plug.name, plug.kind, plug.state.isOn),
        ('Grejalica', DeviceKind.outlet, false),
      );
      expect(d['kasa:50c7bf001122:power']!.state.numericValue, 23.5);

      await backend.send(plug, const TurnOn());
      expect(sent(kasa), {
        'system': {
          'set_relay_state': {'state': 1},
        },
      });
    });

    test('a power strip: each outlet by its child id', () async {
      final (backend, kasa) = await home({
        'alias': 'Razdelnik',
        'model': 'HS300(EU)',
        'mac': '50:C7:BF:00:11:33',
        'children': [
          {'id': '8006AB00', 'state': 1, 'alias': 'TV'},
          {'id': '8006AB01', 'state': 0, 'alias': 'Ruter'},
        ],
      });
      addTearDown(backend.dispose);
      final router =
          backend.current.devices['kasa:50c7bf001133:child8006AB01']!;
      expect((router.name, router.state.isOn), ('Ruter', false));
      await backend.send(router, const TurnOn());
      expect(sent(kasa), {
        'context': {
          'child_ids': ['8006AB01'],
        },
        'system': {
          'set_relay_state': {'state': 1},
        },
      });
    });

    test('a colour bulb: state, and colour as hue/saturation', () async {
      final (backend, kasa) = await home({
        'alias': 'Sijalica',
        'model': 'KL130(EU)',
        'mic_mac': '50C7BF001144',
        'is_color': 1,
        'is_dimmable': 1,
        'is_variable_color_temp': 1,
        'light_state': {
          'on_off': 1,
          'brightness': 60,
          'color_temp': 0,
          'hue': 120,
          'saturation': 100,
        },
      });
      addTearDown(backend.dispose);
      final bulb = backend.current.devices['kasa:50c7bf001144:bulb']!;
      expect(
        (bulb.kind, bulb.state.brightnessPercent, bulb.state.rgb),
        (DeviceKind.rgbLight, 60, const RgbColor(0, 255, 0)),
      );
      await backend.send(bulb, const SetRgbColor(RgbColor(0, 0, 255)));
      final light =
          sent(kasa)['smartlife.iot.smartbulb.lightingservice']! as Map;
      expect(light['transition_light_state'], containsPair('hue', 240));
      expect(light['transition_light_state'], containsPair('saturation', 100));
    });

    test('a device without a MAC is not offered', () {
      expect(DeviceProbe.fromKasa('h', const {'alias': 'x'}), isNull);
    });

    test('an error code becomes a failure', () async {
      final kasa = FakeKasa(
        answer: (_, _) => {
          'system': {
            'set_relay_state': {'err_code': -1},
          },
        },
      );
      final adapter = KasaAdapter(kasa);
      await expectLater(
        adapter.command(
          const ConfiguredDevice(adapter: 'kasa', id: 'x', host: 'h'),
          testDevice('relay'),
          const TurnOn(),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
