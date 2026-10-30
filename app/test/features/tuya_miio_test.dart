import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/aes.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/miio.dart';
import 'package:open_smart_home_lite/features/devices/data/local/tuya.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../lan_fakes.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const plug = '192.168.1.100';
const bulb = '192.168.1.101';
const xiaomi = '192.168.1.102';
const localKey = '0123456789abcdef';
const tokenHex = '00112233445566778899aabbccddeeff';

Uint8List _ret(List<int> payload) =>
    Uint8List.fromList([0, 0, 0, 0, ...payload]);

/// A Tuya plug (3.3: switch 1, power 19) keeping its state.
FakeConversation tuya33Plug(Map<String, Object?> dps) {
  final key = utf8.encode(localKey);
  return (data) {
    final f = tuyaFrames(data).single;
    if (f.cmd == tuyaDpQuery) {
      final q = jsonDecode(utf8.decode(aesEcbDecrypt(key, f.payload))) as Map;
      expect(q['gwId'], 'plug1');
      return [
        tuyaFrame(
          1,
          tuyaDpQuery,
          _ret(aesEcbEncrypt(key, utf8.encode(jsonEncode({'dps': dps})))),
        ),
      ];
    }
    if (f.cmd == tuyaControl) {
      expect(ascii.decode(f.payload.sublist(0, 3)), '3.3');
      final c = jsonDecode(
        utf8.decode(aesEcbDecrypt(key, f.payload.sublist(15))),
      ) as Map;
      dps.addAll((c['dps'] as Map).cast<String, Object?>());
      return [tuyaFrame(2, tuyaControl, _ret(const []))];
    }
    return const [];
  };
}

/// A Tuya bulb on 3.4: session key first, then HMAC'd frames.
FakeConversation tuya34Bulb(Map<String, Object?> dps) {
  final key = utf8.encode(localKey);
  final remote = utf8.encode('remote-nonce-123');
  List<int>? session;
  return (data) {
    final f = tuyaFrames(data, hmac: true).single;
    switch (f.cmd) {
      case tuyaSessionStart:
        final local = aesEcbDecrypt(key, f.payload);
        session = aesEcbEncrypt(key, [
          for (var i = 0; i < 16; i++) local[i] ^ remote[i],
        ], pad: false);
        final mac = hash.Hmac(hash.sha256, key).convert(local).bytes;
        return [
          tuyaFrame(
            1,
            tuyaSessionResponse,
            _ret(aesEcbEncrypt(key, [...remote, ...mac])),
            hmacKey: key,
          ),
        ];
      case tuyaSessionFinish:
        final got = aesEcbDecrypt(key, f.payload);
        expect(got, hash.Hmac(hash.sha256, key).convert(remote).bytes);
        return const [];
      case tuyaDpQueryNew:
        return [
          tuyaFrame(
            2,
            tuyaDpQueryNew,
            _ret(
              aesEcbEncrypt(session!, utf8.encode(jsonEncode({'dps': dps}))),
            ),
            hmacKey: session,
          ),
        ];
      case tuyaControlNew:
        final clear = aesEcbDecrypt(session!, f.payload);
        expect(ascii.decode(clear.sublist(0, 3)), '3.4');
        final c = jsonDecode(utf8.decode(clear.sublist(15))) as Map;
        dps.addAll(((c['data'] as Map)['dps'] as Map).cast<String, Object?>());
        return [tuyaFrame(3, tuyaControlNew, _ret(const []), hmacKey: session)];
    }
    return const [];
  };
}

/// A Xiaomi MIoT plug (power on 2/1) keeping its state.
List<UdpPacket> Function(Uint8List) xiaomiPlug({required List<bool> on}) {
  final token = miioToken(tokenHex);
  Uint8List reply(Map<String, Object?> json) =>
      miioPacket(token, 0x1234, 50, json);
  return (data) {
    if (listEquals(data, miioHello)) {
      final h = ByteData(32)
        ..setUint16(0, 0x2131)
        ..setUint16(2, 32)
        ..setUint32(8, 0x1234)
        ..setUint32(12, 49);
      return [UdpPacket(xiaomi, h.buffer.asUint8List())];
    }
    final req = miioOpen(data, token);
    if (req == null) {
      // A wrong token: the device answers garbage only it can read.
      return [
        UdpPacket(xiaomi, miioPacket(miioToken('ff' * 16), 0x1234, 50, {})),
      ];
    }
    final Object? result = switch (req['method']) {
      'miIO.info' => {'model': 'cuco.plug.v3', 'mac': '64:90:C1:00:00:01'},
      'get_properties' => [
        {'did': '2-1', 'siid': 2, 'piid': 1, 'code': 0, 'value': on.single},
      ],
      'set_properties' => () {
        on[0] = ((req['params'] as List).first as Map)['value'] as bool;
        return [
          {'did': '2-1', 'siid': 2, 'piid': 1, 'code': 0},
        ];
      }(),
      _ => null,
    };
    return [
      UdpPacket(xiaomi, reply({'id': req['id'], 'result': result})),
    ];
  };
}

void main() {
  test('Tuya frames: CRC32 and HMAC, several in one read', () {
    expect(crc32(ascii.encode('123456789')), 0xCBF43926);
    final a = tuyaFrame(1, 8, [1, 2, 3]);
    final b = tuyaFrame(2, 9, [4]);
    final frames = tuyaFrames(Uint8List.fromList([...a, ...b]));
    expect([for (final f in frames) f.cmd], [8, 9]);
    expect(
      [for (final f in frames) f.payload.toList()],
      [
        [1, 2, 3],
        [4],
      ],
    );

    final h = tuyaFrame(3, 7, [9], hmacKey: utf8.encode(localKey));
    expect(h.length, 16 + 1 + 32 + 4);
    expect(tuyaFrames(h, hmac: true).single.payload.toList(), [9]);
  });

  test('Tuya broadcast is read with the firmware key', () {
    final key = hash.md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes;
    final packet = tuyaFrame(
      0,
      0x13,
      _ret(
        aesEcbEncrypt(
          key,
          utf8.encode(
            jsonEncode({
              'ip': plug,
              'gwId': 'plug1',
              'version': '3.3',
              'productKey': 'keyabc',
            }),
          ),
        ),
      ),
    );
    expect(tuyaBroadcast(packet)?['gwId'], 'plug1');
  });

  test('Tuya 3.3 plug and 3.4 bulb: read and switched', () async {
    final plugDps = <String, Object?>{'1': false, '19': 1234};
    final bulbDps = <String, Object?>{
      '20': true,
      '21': 'white',
      '22': 505,
      '23': 500,
      '24': '000003e803e8',
    };
    final tcp = FakeLanTcp({
      '$plug:6668': () => tuya33Plug(plugDps),
      '$bulb:6668': () => tuya34Bulb(bulbDps),
    });
    final backend = LocalBackend(
      [TuyaAdapter(TuyaClient(tcp), keys: (_) async => localKey)],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(
            adapter: 'tuya',
            id: 'plug1',
            host: plug,
            label: 'Bojler',
          ),
          ConfiguredDevice(
            adapter: 'tuya',
            id: 'bulb1',
            host: bulb,
            options: {'version': '3.4'},
          ),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final d = backend.current.devices;
    final p = d['tuya:plug1:switch1']!;
    expect((p.name, p.state.isOn), ('Bojler', false));
    expect(d['tuya:plug1:power']!.state.numericValue, 123.4);
    final light = d['tuya:bulb1:light']!;
    expect(light.kind, DeviceKind.rgbLight);
    expect(light.state.brightnessPercent, 50);
    expect(light.state.colorTemperatureKelvin, 4600);

    await backend.send(p, const TurnOn());
    expect(plugDps['1'], isTrue);
    await backend.send(light, const SetRgbColor(RgbColor(255, 0, 0)));
    expect((bulbDps['21'], bulbDps['24']), ('colour', '000003e801f4'));
  });

  test('Xiaomi: token keys, a plug read and switched, a wrong token', () async {
    final on = [false];
    final udp = FakeLanUdp({'$xiaomi:54321': xiaomiPlug(on: on)});
    final client = MiioClient(udp);
    final info = await client.call(xiaomi, miioToken(tokenHex), 'miIO.info');
    expect((info! as Map)['model'], 'cuco.plug.v3');
    await expectLater(
      client.call(xiaomi, miioToken('ab' * 16), 'miIO.info'),
      throwsA(isA<Object>()),
    );
    expect(() => miioToken('xyz'), throwsA(isA<Object>()));
    expect(miioKind('roborock.vacuum.s5'), MiioKind.vacuum);
    expect(miioKind('chuangmi.plug.m1'), MiioKind.legacyPlug);

    final backend = LocalBackend(
      [MiioAdapter(client, tokens: (_) async => tokenHex)],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(
            adapter: 'miio',
            id: '4660',
            host: xiaomi,
            model: 'cuco.plug.v3',
          ),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    final p = backend.current.devices['miio:4660:switch']!;
    expect((p.kind, p.state.isOn), (DeviceKind.outlet, false));
    await backend.send(p, const TurnOn());
    expect(on.single, isTrue);
  });

  testWidgets('Xiaomi found by its hello, added with its token', (
    tester,
  ) async {
    final udp = FakeLanUdp({
      '$xiaomi:54321': xiaomiPlug(on: [false]),
      '255.255.255.255:54321': (d) => xiaomiPlug(on: [false])(d),
    });
    await pumpApp(tester, size: const Size(800, 1600), udp: udp);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 6);

    Future<void> add(String token) async {
      await tapKey(tester, 'add-miio:4660');
      await settle(tester, 3);
      expect(find.text(en.miioTokenHint), findsOneWidget);
      await tester.enterText(find.byKey(const Key('addDevicePassword')), token);
      await tapKey(tester, 'addDeviceConfirm');
      await settle(tester, 6);
    }

    await add('ab' * 16);
    expect(find.text(en.deviceTokenWrong), findsOneWidget);
    expect(container.read(localHomeProvider).devices, isEmpty);
    await add(tokenHex);
    final added = container.read(localHomeProvider).devices.single;
    expect(added.model, 'cuco.plug.v3');
    expect(container.read(deviceProvider('miio:4660:switch')), isNotNull);
    await unmount(tester);
  });
}
