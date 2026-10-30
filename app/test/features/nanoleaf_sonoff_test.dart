import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/lan_discovery.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/nanoleaf_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/sonoff_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';
import '../lan_fakes.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const panels = '192.168.1.70';
const sonoff = '192.168.1.71';

/// A Nanoleaf (paired once its button was "held" for [pairAfter] tries)
/// and a two-channel Sonoff, each keeping its state.
FakeLanRequests network({int pairAfter = 0}) {
  var tries = 0;
  final leaf = <String, Object?>{
    'on': {'value': false},
    'brightness': {'value': 60},
    'hue': {'value': 120},
    'sat': {'value': 100},
    'ct': {'value': 4000},
    'colorMode': 'hs',
  };
  var effect = 'Northern Lights';
  final outlets = ['off', 'on'];
  const n = '$panels:16021';
  const t = '/api/v1/tok123';
  return FakeLanRequests({
    'POST $n/api/v1/new': (_) => ++tries > pairAfter
        ? jsonResponse({'auth_token': 'tok123'})
        : textResponse('', status: 403),
    'GET $n/api/v1/': (_) => textResponse('', status: 401),
    'GET $n$t/': (_) => jsonResponse({
      'name': 'Shapes',
      'model': 'NL42',
      'serialNo': 'S1234',
      'state': leaf,
      'effects': {
        'select': effect,
        'effectsList': ['Northern Lights', 'Forest'],
      },
    }),
    'PUT $n$t/state': (r) {
      leaf.addAll((r.json! as Map).cast<String, Object?>());
      if ((r.json! as Map).containsKey('ct')) leaf['colorMode'] = 'ct';
      return textResponse('', status: 204);
    },
    'PUT $n$t/effects': (r) {
      effect = (r.json! as Map)['select'] as String;
      return textResponse('', status: 204);
    },
    'POST $sonoff:8081/zeroconf/info': (_) => jsonResponse({
      'seq': 1,
      'error': 0,
      'data': {
        'deviceid': '1000abcdef',
        'fwVersion': '3.6.0',
        'signalStrength': -61,
        'switches': [
          for (var i = 0; i < 2; i++) {'switch': outlets[i], 'outlet': i},
        ],
      },
    }),
    'POST $sonoff:8081/zeroconf/switches': (r) {
      final s = ((r.json! as Map)['data'] as Map)['switches'] as List;
      for (final e in s.cast<Map<String, Object?>>()) {
        outlets[e['outlet'] as int] = e['switch'] as String;
      }
      return jsonResponse({'seq': 2, 'error': 0});
    },
  });
}

void main() {
  test('Nanoleaf: panels and their scene; colour turns them on', () async {
    final http = network();
    final backend = LocalBackend(
      [NanoleafAdapter(http, tokens: (_) async => 'tok123')],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(adapter: 'nanoleaf', id: 's1234', host: panels),
        ],
        demo: false,
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    var light = backend.current.devices['nanoleaf:s1234:light']!;
    expect((light.name, light.state.isOn), ('Shapes', false));
    final fx = backend.current.devices['nanoleaf:s1234:effect']!;
    expect(fx.kind, DeviceKind.select);
    expect(fx.state.textValue, 'Northern Lights');

    await backend.send(light, const SetRgbColor(RgbColor(0, 0, 255)));
    await pumpEventQueue();
    light = backend.current.devices['nanoleaf:s1234:light']!;
    expect(light.state.isOn, isTrue);
    expect(light.state.rgb, const RgbColor(0, 0, 255));
    await backend.send(fx, const SelectOption('Forest'));
    await pumpEventQueue();
    expect(
      backend.current.devices['nanoleaf:s1234:effect']!.state.textValue,
      'Forest',
    );
  });

  test('Sonoff DIY: two channels, each switched alone', () async {
    final http = network();
    final found = await sonoffProbe(http, sonoff);
    expect(found?.id, '1000abcdef');
    final backend = LocalBackend(
      [SonoffAdapter(http)],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(
            adapter: 'sonoff',
            id: '1000abcdef',
            host: sonoff,
            label: 'Bojler',
          ),
        ],
        demo: false,
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    final first = backend.current.devices['sonoff:1000abcdef:switch0']!;
    expect((first.name, first.state.isOn), ('Bojler 1', false));
    expect(
      backend.current.devices['sonoff:1000abcdef:switch1']!.state.isOn,
      isTrue,
    );
    await backend.send(first, const TurnOn());
    await pumpEventQueue();
    expect(
      backend.current.devices['sonoff:1000abcdef:switch0']!.state.isOn,
      isTrue,
    );
    expect(
      http.requests.last.uri.path,
      '/zeroconf/info',
      reason: 'read again after the command',
    );
  });

  testWidgets('Nanoleaf found by mDNS, paired with its button, added', (
    tester,
  ) async {
    final http = network(pairAfter: 2);
    final credentials = await pumpApp(
      tester,
      size: const Size(800, 1600),
      requests: http,
      discovery: FakeLanDiscovery(const [
        LanService(
          name: 'Shapes 1A2B',
          host: panels,
          port: 16021,
          type: LanService.nanoleafType,
          txt: {'id': 'S1234', 'md': 'NL42'},
        ),
      ]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 4);
    await tapKey(tester, 'add-nanoleaf:s1234');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 2);
    expect(find.text(en.nanoleafLinkBody), findsOneWidget);
    // Two tries before the button was held long enough.
    await tester.pump(const Duration(seconds: 7));
    await settle(tester, 6);
    expect(find.byKey(const Key('deviceLink')), findsNothing);
    expect(credentials.values['device:nanoleaf:s1234'], 'tok123');
    expect(
      container.read(deviceProvider('nanoleaf:s1234:light'))?.name,
      'Shapes',
    );
    await unmount(tester);
  });
}
