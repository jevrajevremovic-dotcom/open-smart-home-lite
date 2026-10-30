import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/add_device/data/device_probe.dart';
import 'package:open_smart_home_lite/features/devices/application/device_command_service.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/shelly_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/tasmota_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/wled_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_http.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/home_snapshot.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';

// What real devices answer (trimmed to the fields that matter).
const plus1pm = '192.168.1.21';
const plus2pmCover = '192.168.1.22';
const shelly25 = '192.168.1.23';
const wled = '192.168.1.30';
const tasmota = '192.168.1.40';

Map<String, Map<String, Object? Function(Map<String, Object?>)>> network() {
  var switchOn = true;
  var coverPos = 40;
  final relays = [true, false];
  final tasmotaPower = ['ON', 'OFF'];
  var wledState = <String, Object?>{
    'on': true,
    'bri': 128,
    'ps': 2,
    'seg': [
      {
        'fx': 1,
        'col': [
          [255, 160, 0],
          [0, 0, 0],
        ],
      },
    ],
  };
  return {
    plus1pm: {
      '/shelly': (_) => {
        'name': 'Hodnik',
        'id': 'shellyplus1pm-a8032ab12345',
        'mac': 'A8032AB12345',
        'model': 'SNSW-001P16EU',
        'gen': 2,
        'app': 'Plus1PM',
      },
      '/rpc/Shelly.GetConfig': (_) => {
        'switch:0': {'id': 0, 'name': null},
        'sys': {
          'device': {'name': 'Hodnik'},
        },
      },
      '/rpc/Shelly.GetStatus': (_) => {
        'switch:0': {'id': 0, 'output': switchOn, 'apower': 12.5},
        'input:0': {'id': 0, 'state': false},
        'wifi': {'rssi': -58},
        'sys': {'uptime': 100},
      },
      '/rpc/Switch.Set': (q) {
        switchOn = q['on'] == true;
        return {'was_on': !switchOn};
      },
    },
    plus2pmCover: {
      '/shelly': (_) => {
        'mac': 'A8032AB00002',
        'gen': 2,
        'app': 'Plus2PM',
        'profile': 'cover',
      },
      '/rpc/Shelly.GetConfig': (_) => {
        'cover:0': {'id': 0, 'name': 'Roletna'},
      },
      '/rpc/Shelly.GetStatus': (_) => {
        'cover:0': {
          'id': 0,
          'state': 'stopped',
          'current_pos': coverPos,
          'pos_control': true,
          'apower': 0,
        },
      },
      '/rpc/Cover.GoToPosition': (q) {
        coverPos = q['pos']! as int;
        return null;
      },
    },
    shelly25: {
      '/shelly': (_) => {
        'type': 'SHSW-25',
        'mac': '3C6105AABBCC',
        'auth': false,
        'num_outputs': 2,
      },
      '/settings': (_) => {
        'name': null,
        'mode': 'relay',
        'relays': [
          {'name': 'Levo'},
          {'name': null},
        ],
      },
      '/status': (_) => {
        'relays': [
          for (final on in relays) {'ison': on},
        ],
        'meters': [
          {'power': 5.0},
          {'power': 0},
        ],
        'wifi_sta': {'rssi': -70},
      },
      '/relay/1': (q) {
        if (q['turn'] == 'toggle') relays[1] = !relays[1];
        return {'ison': relays[1]};
      },
    },
    wled: {
      '/json/info': (_) => {
        'ver': '0.14.4',
        'name': 'Traka',
        'brand': 'WLED',
        'mac': 'e8db84aabbcc',
        'wifi': {'rssi': -60},
      },
      '/json/eff': (_) => ['Solid', 'Blink', 'Rainbow'],
      '/presets.json': (_) => {
        '0': <String, Object?>{},
        '1': {'n': 'Jutro'},
        '2': {'n': 'Veče'},
      },
      '/json/state': (data) {
        final body = data['body'];
        if (body is Map<String, Object?>) wledState = {...wledState, ...body};
        return wledState;
      },
    },
    tasmota: {
      '/cm': (q) {
        final cmnd = q['cmnd']! as String;
        if (cmnd == 'Status 0') {
          return {
            'Status': {
              'DeviceName': 'Sonoff',
              'FriendlyName': ['Bojler', 'Pumpa'],
            },
            'StatusFWR': {'Hardware': 'ESP8266EX'},
            'StatusNET': {'Mac': 'DC:4F:22:11:22:33'},
            'StatusSTS': {
              'POWER1': tasmotaPower[0],
              'POWER2': tasmotaPower[1],
              'Wifi': {'Signal': -62},
            },
            'StatusSNS': {
              'ENERGY': {'Power': 1800},
              'DS18B20': {'Temperature': 54.5},
              'TempUnit': 'C',
            },
          };
        }
        final m = RegExp(r'^Power(\d) (On|Off|Toggle)$').firstMatch(cmnd);
        if (m == null) return {'Command': 'Unknown'};
        final i = int.parse(m.group(1)!) - 1;
        tasmotaPower[i] = switch (m.group(2)) {
          'On' => 'ON',
          'Off' => 'OFF',
          _ => tasmotaPower[i] == 'ON' ? 'OFF' : 'ON',
        };
        return {'POWER${i + 1}': tasmotaPower[i]};
      },
    },
  };
}

/// A request to `host` and `path` with these query parameters (or body).
Matcher hasRequest((String, String, Object?) request) => anyElement(
  predicate<(String, String, Object?)>(
    (r) =>
        r.$1 == request.$1 &&
        r.$2 == request.$2 &&
        equals(request.$3).matches(r.$3, {}),
    'request $request',
  ),
);

ConfiguredDevice configured(String adapter, String mac, String host) =>
    ConfiguredDevice(adapter: adapter, id: mac, host: host);

void main() {
  late FakeLanHttp http;
  late LocalBackend backend;

  Future<HomeSnapshot> settled() async {
    await backend.refresh();
    await Future<void>.delayed(Duration.zero);
    return backend.current;
  }

  setUp(() {
    http = FakeLanHttp(network());
    backend = LocalBackend(
      [
        ShellyAdapter(http, pollEvery: const Duration(hours: 1)),
        WledAdapter(http, pollEvery: const Duration(hours: 1)),
        TasmotaAdapter(http, pollEvery: const Duration(hours: 1)),
      ],
      home: LocalHome(
        devices: [
          configured('shelly', 'a8032ab12345', plus1pm),
          configured('shelly', 'a8032ab00002', plus2pmCover),
          configured(
            'shelly',
            '3c6105aabbcc',
            shelly25,
          ).copyWith(model: 'SHSW-25'),
          configured('wled', 'e8db84aabbcc', wled),
          configured('tasmota', 'dc4f22112233', tasmota),
        ],
      ),
    )..start();
  });
  tearDown(() => backend.dispose());

  test('Shelly Gen2: a relay with its power meter', () async {
    final devices = (await settled()).devices;
    final relay = devices['shelly:a8032ab12345:switch0']!;
    expect(relay.name, 'Hodnik');
    expect(relay.kind, DeviceKind.switchDevice);
    expect(relay.state.isOn, isTrue);
    expect(relay.deviceId, 'shelly:a8032ab12345');
    expect(relay.metadata.signalStrength, -58);
    final power = devices['shelly:a8032ab12345:switch0_power']!;
    expect(power.kind, DeviceKind.powerMeter);
    expect(power.state.numericValue, 12.5);
    expect(power.state.unit, 'W');
    expect(devices.keys.where((k) => k.contains('input')), isEmpty);
  });

  test('Shelly Gen2: a command, then the new state', () async {
    final relay = (await settled()).devices['shelly:a8032ab12345:switch0']!;
    await DeviceCommandService(backend).execute(relay, const TurnOff());
    expect(
      http.requests,
      hasRequest((plus1pm, '/rpc/Switch.Set', {'id': 0, 'on': false})),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      backend.current.devices['shelly:a8032ab12345:switch0']!.state.isOn,
      isFalse,
    );
  });

  test('Shelly Gen2: a roller shutter goes to a position', () async {
    final cover = (await settled()).devices['shelly:a8032ab00002:cover0']!;
    expect(cover.name, 'Roletna');
    expect(cover.kind, DeviceKind.blind);
    expect(cover.supports(Capability.position), isTrue);
    expect(cover.state.position, 40);
    expect(cover.state.coverState, CoverState.open);

    await backend.send(cover, const SetCoverPosition(70));
    await Future<void>.delayed(Duration.zero);
    expect(
      backend.current.devices['shelly:a8032ab00002:cover0']!.state.position,
      70,
    );
  });

  test('Shelly Gen1: two relays, named or numbered', () async {
    final devices = (await settled()).devices;
    final left = devices['shelly:3c6105aabbcc:relay0']!;
    final right = devices['shelly:3c6105aabbcc:relay1']!;
    expect((left.name, left.state.isOn), ('Levo', true));
    expect((right.name, right.state.isOn), ('SHSW-25 2', false));
    expect(devices['shelly:3c6105aabbcc:meter0_power']!.state.numericValue, 5);

    await backend.send(right, const Toggle());
    expect(http.requests.last.$2, '/status');
    expect(
      http.requests,
      hasRequest((shelly25, '/relay/1', {'turn': 'toggle'})),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      backend.current.devices['shelly:3c6105aabbcc:relay1']!.state.isOn,
      isTrue,
    );
  });

  test('WLED: brightness, colour and commands as JSON', () async {
    final strip = (await settled()).devices['wled:e8db84aabbcc:light']!;
    expect(strip.name, 'Traka');
    expect(strip.kind, DeviceKind.rgbLight);
    expect(strip.state.brightnessPercent, 50);
    expect(strip.state.rgb, const RgbColor(255, 160, 0));

    await backend.send(strip, const SetRgbColor(RgbColor(0, 0, 255)));
    expect(
      http.requests,
      hasRequest((
        wled,
        '/json/state',
        {
          'body': {
            'on': true,
            'seg': [
              {
                'col': [
                  [0, 0, 255],
                ],
              },
            ],
          },
        },
      )),
    );
    await backend.send(strip, const SetBrightness(100));
    await Future<void>.delayed(Duration.zero);
    final after = backend.current.devices['wled:e8db84aabbcc:light']!;
    expect(after.state.brightnessPercent, 100);
    expect(after.state.rgb, const RgbColor(0, 0, 255));
  });

  test(
    'a device that stops answering stays, unavailable; then comes back',
    () async {
      final saved = http.answers.remove(plus1pm)!;
      var devices = (await settled()).devices;
      expect(
        devices['shelly:a8032ab12345:device']!.available,
        isFalse,
        reason: 'never heard from: a placeholder',
      );

      http.answers[plus1pm] = saved;
      devices = (await settled()).devices;
      expect(devices['shelly:a8032ab12345:switch0']!.available, isTrue);
      expect(devices.containsKey('shelly:a8032ab12345:device'), isFalse);

      http.answers.remove(plus1pm);
      devices = (await settled()).devices;
      final relay = devices['shelly:a8032ab12345:switch0']!;
      expect(relay.available, isFalse);
      expect(relay.state.isOn, isTrue, reason: 'last known state');
    },
  );

  test('the household\'s names and rooms; removing a device', () async {
    await settled();
    backend.configure(
      backend.home.copyWith(
        rooms: const [Room(id: 'hall', name: 'Hodnik')],
        roomOf: {'shelly:a8032ab12345': 'hall'},
        names: {'shelly:a8032ab12345:switch0': 'Svetlo u hodniku'},
      ),
    );
    var devices = backend.current.devices;
    final relay = devices['shelly:a8032ab12345:switch0']!;
    expect(relay.name, 'Svetlo u hodniku');
    expect(relay.roomId, 'hall', reason: 'the physical device\'s room');
    expect(devices['shelly:a8032ab12345:switch0_power']!.roomId, 'hall');
    expect(backend.current.rooms.keys, ['hall']);

    backend.configure(
      backend.home.copyWith(
        devices: [
          for (final d in backend.home.devices)
            if (d.adapter != 'shelly') d,
        ],
      ),
    );
    devices = backend.current.devices;
    expect(devices.keys.where((k) => k.startsWith('shelly:')), isEmpty);
    expect(devices, contains('wled:e8db84aabbcc:light'));
  });

  test('probe: Shelly Gen1, Gen2 and WLED; anything else is nothing', () async {
    final probe = DeviceProbe(http, noEsphome);
    final gen2 = (await probe.probe(plus1pm))!;
    expect(gen2.brand, 'Shelly');
    expect(gen2.title, 'Hodnik');
    expect(gen2.device.key, 'shelly:a8032ab12345');
    expect(gen2.device.model, 'Plus1PM');
    expect((await probe.probe(shelly25))!.device.model, 'SHSW-25');
    final strip = (await probe.probe(wled))!;
    expect((strip.brand, strip.device.key), ('WLED', 'wled:e8db84aabbcc'));
    expect(await probe.probe('192.168.1.99'), isNull);
  });

  test('WLED: the effect and the preset are choices', () async {
    final devices = (await settled()).devices;
    final fx = devices['wled:e8db84aabbcc:effect']!;
    expect(fx.kind, DeviceKind.select);
    expect(fx.limits.options, ['Solid', 'Blink', 'Rainbow']);
    expect(fx.state.textValue, 'Blink');
    final preset = devices['wled:e8db84aabbcc:preset']!;
    expect(preset.limits.options, ['Jutro', 'Veče']);
    expect(preset.state.textValue, 'Veče');

    await backend.send(fx, const SelectOption('Rainbow'));
    expect(
      http.requests,
      hasRequest((
        wled,
        '/json/state',
        {
          'body': {
            'on': true,
            'seg': [
              {'fx': 2},
            ],
          },
        },
      )),
    );
    await backend.send(preset, const SelectOption('Jutro'));
    expect(
      http.requests,
      hasRequest((
        wled,
        '/json/state',
        {
          'body': {'ps': 1},
        },
      )),
    );
  });

  test(
    'Tasmota: two relays by their friendly names, power and a sensor',
    () async {
      final devices = (await settled()).devices;
      final boiler = devices['tasmota:dc4f22112233:power1']!;
      final pump = devices['tasmota:dc4f22112233:power2']!;
      expect((boiler.name, boiler.state.isOn), ('Bojler', true));
      expect((pump.name, pump.state.isOn), ('Pumpa', false));
      expect(boiler.metadata.signalStrength, -62);
      expect(
        devices['tasmota:dc4f22112233:energy_power']!.state.numericValue,
        1800,
      );
      final water = devices['tasmota:dc4f22112233:ds18b20_temperature']!;
      expect(
        (water.kind, water.state.currentTemperature),
        (DeviceKind.temperatureSensor, 54.5),
      );

      await backend.send(pump, const TurnOn());
      expect(
        http.requests,
        hasRequest((tasmota, '/cm', {'cmnd': 'Power2 On'})),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        backend.current.devices['tasmota:dc4f22112233:power2']!.state.isOn,
        isTrue,
      );
    },
  );

  test(
    'Shelly with a password: asked with it; without it, unavailable',
    () async {
      final locked = FakeLanHttp(network(), passwords: {plus1pm: 'tajna'});
      String? password;
      final b = LocalBackend(
        [
          ShellyAdapter(
            locked,
            passwords: (_) async => password,
            pollEvery: const Duration(hours: 1),
          ),
        ],
        home: LocalHome(
          devices: [
            configured(
              'shelly',
              'a8032ab12345',
              plus1pm,
            ).copyWith(secured: true),
          ],
        ),
      )..start();
      addTearDown(b.dispose);
      await b.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        b.current.devices['shelly:a8032ab12345:device']!.available,
        isFalse,
      );

      password = 'tajna';
      b.configure(b.home); // a new password clears what the adapter knew
      await b.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        b.current.devices['shelly:a8032ab12345:switch0']!.available,
        isTrue,
      );
    },
  );

  test('HTTP Digest answer (RFC 7616, SHA-256 example)', () {
    final header = digestAuthorization(
      challenge:
          'Digest realm="http-auth@example.org", qop="auth, auth-int", '
          'algorithm=SHA-256, '
          'nonce="7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v", '
          'opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS"',
      method: 'GET',
      uri: '/dir/index.html',
      auth: const LanAuth.digest('Mufasa', 'Circle of Life'),
      cnonce: 'f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ',
    )!;
    expect(
      header,
      contains(
        'response="753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1"',
      ),
    );
    expect(
      header,
      contains('opaque="FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS"'),
    );
    expect(
      digestAuthorization(
        challenge: 'Basic realm="x"',
        method: 'GET',
        uri: '/',
        auth: const LanAuth.digest('a', 'b'),
        cnonce: 'c',
      ),
      isNull,
    );
  });

  test('probe: Tasmota, and a Shelly that asks for a password', () async {
    final probe = DeviceProbe(
      FakeLanHttp({
        ...network(),
        '192.168.1.24': {
          '/shelly': (_) => {'mac': 'A8032AB00003', 'gen': 2, 'auth_en': true},
        },
      }),
      noEsphome,
    );
    final t = (await probe.probe(tasmota))!;
    expect(
      (t.brand, t.title, t.device.key),
      ('Tasmota', 'Sonoff', 'tasmota:dc4f22112233'),
    );
    expect((await probe.probe('192.168.1.24'))!.needsPassword, isTrue);
    expect((await probe.probe(plus1pm))!.needsPassword, isFalse);
  });

  test('stored home is read tolerantly', () {
    final home = LocalHome.fromJson({
      'rooms': [
        {'id': 'a', 'name': 'Kuhinja'},
        {'id': 3},
      ],
      'devices': [
        configured('wled', 'e8db84aabbcc', wled).toJson(),
        {'adapter': 'shelly'},
      ],
      'names': {'x': 'Y', 'z': 1},
    });
    expect(home.rooms.single.name, 'Kuhinja');
    expect(home.devices.single.key, 'wled:e8db84aabbcc');
    expect(home.names, {'x': 'Y'});
    expect(LocalHome.fromJson(home.toJson()).devices, home.devices);
    expect(LocalHome.fromJson(null).devices, isEmpty);
  });
}
