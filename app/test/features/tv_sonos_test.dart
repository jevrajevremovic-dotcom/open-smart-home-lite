import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';

import 'dart:typed_data';

import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lg_tv_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/roku_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/samsung_tv_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/sonos_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ssdp.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../lan_fakes.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const roku = '192.168.1.80';
const samsung = '192.168.1.81';
const lg = '192.168.1.82';
const sonos = '192.168.1.83';

const rokuInfo = '''<?xml version="1.0" encoding="UTF-8" ?>
<device-info>
  <serial-number>X01234</serial-number>
  <model-name>Roku Ultra</model-name>
  <user-device-name>Dnevna</user-device-name>
  <is-tv>false</is-tv>
  <power-mode>PowerOn</power-mode>
</device-info>''';

String sonosAnswer(String action, String inner) =>
    '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
    '<u:${action}Response xmlns:u="urn:x">$inner</u:${action}Response>'
    '</s:Body></s:Envelope>';

FakeLanRequests http() {
  var playing = true;
  return FakeLanRequests({
    'GET $roku:8060/query/device-info': (_) => textResponse(rokuInfo),
    'GET $roku:8060/query/active-app': (_) =>
        textResponse('<active-app><app id="12">Netflix</app></active-app>'),
    'GET $roku:8060/query/media-player': (_) =>
        textResponse('<player error="false" state="play"></player>'),
    'POST $roku:8060/keypress/Up': (_) => textResponse(''),
    'GET $samsung:8001/api/v2/': (_) => jsonResponse({
      'name': '[TV] Samsung Q60',
      'device': {
        'id': 'uuid:0aa1-bb22',
        'name': '[TV] Samsung Q60',
        'modelName': 'QE55Q60',
        'PowerState': 'on',
        'wifiMac': 'AA:BB:CC:00:11:22',
      },
    }),
    'GET $sonos:1400/xml/device_description.xml': (_) => textResponse(
      '<root><device><roomName>Kuhinja</roomName><modelName>Sonos One</modelName>'
      '<UDN>uuid:RINCON_B8E937000000</UDN></device></root>',
    ),
    'POST $sonos:1400/MediaRenderer/AVTransport/Control': (r) {
      final action = r.headers['soapaction']!
          .split('#')
          .last
          .replaceAll('"', '');
      if (action == 'Pause') playing = false;
      if (action == 'Play') playing = true;
      return textResponse(switch (action) {
        'GetTransportInfo' => sonosAnswer(
          action,
          '<CurrentTransportState>${playing ? 'PLAYING' : 'PAUSED_PLAYBACK'}</CurrentTransportState>',
        ),
        'GetPositionInfo' => sonosAnswer(
          action,
          '<TrackMetaData>${xmlEscape('<DIDL-Lite><item><dc:title>Kiša</dc:title><dc:creator>Bend</dc:creator></item></DIDL-Lite>')}</TrackMetaData>',
        ),
        _ => sonosAnswer(action, ''),
      });
    },
    'POST $sonos:1400/MediaRenderer/RenderingControl/Control': (r) {
      final action = r.headers['soapaction']!
          .split('#')
          .last
          .replaceAll('"', '');
      return textResponse(switch (action) {
        'GetVolume' => sonosAnswer(action, '<CurrentVolume>23</CurrentVolume>'),
        'GetMute' => sonosAnswer(action, '<CurrentMute>0</CurrentMute>'),
        _ => sonosAnswer(action, ''),
      });
    },
  });
}

/// The Samsung (asks once, then gives token `t1`) and an LG that pairs
/// and answers volume, apps and its pointer socket.
FakeLanSockets sockets({bool samsungAllows = true}) => FakeLanSockets({
  'wss://$samsung:8002/api/v2/channels/samsung.remote.control': (m, uri) {
    if (m.isNotEmpty) return const [];
    final token = uri.queryParameters['token'];
    if (token == null && !samsungAllows) {
      return [
        jsonEncode({'event': 'ms.channel.unauthorized'}),
      ];
    }
    return [
      jsonEncode({
        'event': 'ms.channel.connect',
        'data': {'token': token ?? 't1'},
      }),
    ];
  },
  'wss://$lg:3001/': (m, _) {
    if (m.isEmpty) return const [];
    final j = jsonDecode(m) as Map;
    if (j['type'] == 'register') {
      return [
        jsonEncode({
          'type': 'registered',
          'id': 'register_0',
          'payload': {'client-key': 'k9'},
        }),
      ];
    }
    final payload = switch (j['uri']) {
      'ssap://audio/getVolume' => {
        'volumeStatus': {'volume': 12, 'muteStatus': false},
      },
      'ssap://com.webos.applicationManager/getForegroundAppInfo' => {
        'appId': 'com.webos.app.livetv',
      },
      'ssap://com.webos.service.networkinput/getPointerInputSocket' => {
        'socketPath': 'wss://$lg:3001/pointer',
      },
      'ssap://com.webos.service.connectionmanager/getinfo' => {
        'wiredInfo': {'macAddress': 'a0:b1:c2:d3:e4:f5'},
      },
      _ => <String, Object?>{},
    };
    return [
      jsonEncode({
        'type': 'response',
        'id': j['id'],
        'payload': {'returnValue': true, ...payload},
      }),
    ];
  },
  'wss://$lg:3001/pointer': (_, _) => const [],
});

void main() {
  test('Roku: what it is, what is on, a key', () async {
    final r = http();
    final backend = LocalBackend(
      [RokuAdapter(r)],
      home: const LocalHome(
        devices: [ConfiguredDevice(adapter: 'roku', id: 'x01234', host: roku)],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    final tv = backend.current.devices['roku:x01234:tv']!;
    expect(tv.kind, DeviceKind.mediaPlayer, reason: 'a player, not a Roku TV');
    expect(
      (tv.name, tv.state.raw, tv.state.mediaTitle),
      ('Dnevna', 'playing', 'Netflix'),
    );
    await backend.send(tv, const PressTvKey(TvKey.up));
    expect(r.pathsTo('POST'), contains('/keypress/Up'));
  });

  test('Samsung: allowed on the TV; keys after the TV says ready', () async {
    final ws = sockets();
    final linked = await samsungLink(ws, samsung);
    expect((linked?.token, linked?.certificate), ('t1', 'cert-1'));
    final udp = FakeLanUdp(const {});
    final backend = LocalBackend(
      [SamsungTvAdapter(http(), ws, udp, tokens: (_) async => 't1')],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(
            adapter: 'samsung',
            id: '0aa1-bb22',
            host: samsung,
            options: {'mac': 'aabbcc001122', 'cert': 'cert-1'},
          ),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    final tv = backend.current.devices['samsung:0aa1-bb22:tv']!;
    expect((tv.name, tv.state.isOn), ('Samsung Q60', true));
    await backend.send(tv, const StepVolume(up: true));
    expect(ws.sent.last, contains('KEY_VOLUP'));
    expect(ws.opened.last.queryParameters['token'], 't1');
    // Someone else answering with another certificate: refused.
    ws.certificate = 'cert-other';
    await expectLater(
      backend.send(tv, const StepVolume(up: true)),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.certificate,
        ),
      ),
    );
    ws.certificate = 'cert-1';

    await backend.send(
      parseSamsungTv(backend.home.devices.single, null),
      const TurnOn(),
    );
    final (host, port, packet) = udp.sent.single;
    expect((host, port, packet.length), ('255.255.255.255', 9, 102));
    expect(packet.sublist(6, 12), [0xAA, 0xBB, 0xCC, 0x00, 0x11, 0x22]);
  });

  test('Samsung refused on the TV: no token', () async {
    expect(await samsungLink(sockets(samsungAllows: false), samsung), isNull);
  });

  test('LG: paired, volume and app read, a button by the pointer', () async {
    final ws = sockets();
    final linked = await lgLink(ws, lg);
    expect((linked?.key, linked?.mac), ('k9', 'a0b1c2d3e4f5'));

    final backend = LocalBackend(
      [LgTvAdapter(ws, FakeLanUdp(const {}), keys: (_) async => 'k9')],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(adapter: 'lg', id: 'tv1', host: lg, label: 'TV'),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue(times: 50);
    final tv = backend.current.devices['lg:tv1:tv']!;
    expect(
      (tv.state.isOn, tv.state.volumePercent, tv.state.source),
      (true, 12, 'livetv'),
    );
    await backend.send(tv, const SetMute(true));
    expect(ws.sent, contains(contains('ssap://audio/setMute')));
    await backend.send(tv, const PressTvKey(TvKey.left));
    expect(ws.sent, contains('type:button\nname:LEFT\n\n'));
  });

  test('Sonos: playing, track from DIDL, volume; pause', () async {
    final r = http();
    final backend = LocalBackend(
      [SonosAdapter(r)],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(
            adapter: 'sonos',
            id: 'rincon_b8e937000000',
            host: sonos,
            label: 'Kuhinja',
          ),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    var speaker = backend.current.devices['sonos:rincon_b8e937000000:speaker']!;
    expect(
      (speaker.state.raw, speaker.state.mediaTitle, speaker.state.mediaArtist),
      ('playing', 'Kiša', 'Bend'),
    );
    expect(speaker.state.volumePercent, 23);
    await backend.send(speaker, const MediaPlayPause());
    await pumpEventQueue();
    speaker = backend.current.devices['sonos:rincon_b8e937000000:speaker']!;
    expect(speaker.state.raw, 'paused');
    expect(
      r.requests.map((q) => q.headers['soapaction']),
      contains(contains('#Pause')),
    );
  });

  testWidgets('Samsung TV found by SSDP, allowed on the TV, its remote works', (
    tester,
  ) async {
    final ws = sockets();
    final udp = FakeLanUdp({
      '239.255.255.250:1900': (data) => utf8.decode(data).contains('samsung')
          ? udpAnswerText(
              samsung,
              'HTTP/1.1 200 OK\r\nST: urn:samsung.com:device:RemoteControlReceiver:1\r\n'
              'LOCATION: http://$samsung:7676/rcr/\r\n\r\n',
            )
          : const [],
    });
    final credentials = await pumpApp(
      tester,
      size: const Size(800, 1600),
      udp: udp,
      requests: http(),
      sockets: ws,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 6);
    await tapKey(tester, 'add-samsung:0aa1-bb22');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 2);
    expect(find.text(en.tvLinkBody), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester, 6);
    expect(credentials.values['device:samsung:0aa1-bb22'], 't1');
    final home = container.read(localHomeProvider);
    expect(home.devices.single.options['mac'], 'aabbcc001122');
    expect(
      home.devices.single.options['cert'],
      'cert-1',
      reason: 'the TV\'s certificate, required from now on',
    );

    const id = 'samsung:0aa1-bb22:tv';
    expect(container.read(deviceProvider(id))?.state.isOn, isTrue);
    await goTo(tester, AppRoutes.device(id));
    await settle(tester, 4);
    await tester.ensureVisible(find.byKey(const ValueKey('tvKey-up')));
    await tapKey(tester, 'tvKey-up');
    await settle(tester, 4);
    expect(ws.sent.last, contains('KEY_UP'));
    await unmount(tester);
  });
}

List<UdpPacket> udpAnswerText(String host, String text) => [
  UdpPacket(host, Uint8List.fromList(utf8.encode(text))),
];
