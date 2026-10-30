import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/aes.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_advert.dart';
import 'package:open_smart_home_lite/features/devices/data/local/broadlink.dart';
import 'package:open_smart_home_lite/features/devices/data/local/camera_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';

import '../helpers.dart';
import '../lan_fakes.dart';
import '../test_images.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const rm = '192.168.1.110';
const cam = '192.168.1.111';
const rmMac = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66];
const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 0xFF, 0xD9];

const _initialKey = [
  0x09, 0x76, 0x28, 0x34, 0x3f, 0xe9, 0x9e, 0x23, //
  0x76, 0x5c, 0x15, 0x13, 0xac, 0xcf, 0x8b, 0x02,
];
const _iv = [
  0x56, 0x2e, 0x17, 0x99, 0x6d, 0x09, 0x3d, 0x28, //
  0xdd, 0xb3, 0xba, 0x69, 0x5a, 0x2e, 0x6f, 0x58,
];

/// An RM4 mini: answers the hello, authenticates (new key), learns a code
/// on the second check, and records what it was told to send.
class FakeRm {
  final sessionKey = List<int>.generate(16, (i) => 0xA0 + i);
  var checks = 0;
  final sent = <List<int>>[];

  Uint8List answer(int type, int error, List<int> payload, List<int> key) {
    final p = Uint8List(0x38);
    final b = ByteData.sublistView(p)
      ..setUint16(0x26, type, Endian.little)
      ..setInt16(0x22, error, Endian.little);
    final padded = [
      ...payload,
      ...List.filled((16 - payload.length % 16) % 16, 0),
    ];
    b.setUint16(0x20, 0, Endian.little);
    return Uint8List.fromList([...p, ...aesCbcRaw(true, key, _iv, padded)]);
  }

  List<UdpPacket> handle(Uint8List data) {
    if (data.length == 0x30) {
      final r = Uint8List(0x80);
      ByteData.sublistView(r).setUint16(0x34, 0x5F36, Endian.little);
      r.setRange(0x3A, 0x40, rmMac);
      r.setRange(0x40, 0x46, utf8.encode('Klima1'));
      return [UdpPacket(rm, r)];
    }
    final type = ByteData.sublistView(data).getUint16(0x26, Endian.little);
    if (type == 0x65) {
      final clear = aesCbcRaw(false, _initialKey, _iv, data.sublist(0x38));
      expect(ascii.decode(clear.sublist(0x30, 0x36)), 'Test 1');
      return [
        UdpPacket(
          rm,
          answer(0x3E9, 0, [1, 0, 0, 0, ...sessionKey], _initialKey),
        ),
      ];
    }
    final clear = aesCbcRaw(false, sessionKey, _iv, data.sublist(0x38));
    final b = ByteData.sublistView(clear);
    final len = b.getUint16(0, Endian.little);
    final cmd = b.getUint32(2, Endian.little);
    final body = clear.sublist(6, 2 + len);
    switch (cmd) {
      case 0x02:
        sent.add(body);
        return [UdpPacket(rm, answer(0x3EE, 0, const [], sessionKey))];
      case 0x03:
        return [UdpPacket(rm, answer(0x3EE, 0, const [], sessionKey))];
      case 0x04:
        // Nothing heard on the first check.
        if (++checks < 2) {
          return [UdpPacket(rm, answer(0x3EE, -10, const [], sessionKey))];
        }
        return [
          UdpPacket(
            rm,
            answer(0x3EE, 0, [
              8,
              0,
              4,
              0,
              0,
              0,
              0x26,
              0x00,
              0x10,
              0x20,
              0,
              0,
            ], sessionKey),
          ),
        ];
    }
    return const [];
  }
}

void main() {
  test('Broadlink: hello, auth with a new key, learn, send', () async {
    final device = FakeRm();
    final udp = FakeLanUdp({
      '255.255.255.255:80': device.handle,
      '$rm:80': device.handle,
    });
    final client = BroadlinkClient(udp);
    final found = (await client.discover()).single;
    expect((found.devtype, found.name), (0x5F36, 'Klima1'));
    expect(broadlinkMacText(found.mac), '665544332211');

    final config = ConfiguredDevice(
      adapter: 'broadlink',
      id: broadlinkMacText(found.mac),
      host: rm,
      options: {'devtype': found.devtype.toRadixString(16)},
    );
    final s = client.session(config);
    expect(s.rm4, isTrue);
    final code = await s.learn(wait: const Duration(seconds: 5));
    expect(code, [0x26, 0x00, 0x10, 0x20], reason: 'trailing zeros trimmed');

    final backend = LocalBackend(
      [BroadlinkAdapter(client)],
      home: LocalHome(
        devices: [
          config.copyWith(
            label: 'Daljinski',
            options: {...config.options, 'btn:Klima on': base64.encode(code!)},
          ),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    final d = backend.current.devices;
    expect(d['broadlink:665544332211:remote']!.kind, DeviceKind.remote);
    final button = d['broadlink:665544332211:btn_klima_on']!;
    expect(
      (button.kind, button.name),
      (DeviceKind.button, 'Daljinski · Klima on'),
    );
    await backend.send(button, const Activate());
    expect(device.sent.single, [0x26, 0x00, 0x10, 0x20]);
  });

  test('camera: snapshot behind Digest; not an image refused', () async {
    final http = FakeLanRequests({
      'GET $cam/cgi-bin/snapshot.cgi': (r) => r.auth?.user == 'admin'
          ? LanResponse(200, Uint8List.fromList(jpeg))
          : textResponse('', status: 401),
      'GET $cam/index.html': (_) => textResponse('<html>'),
    });
    final url = Uri.parse('http://$cam/cgi-bin/snapshot.cgi');
    final image = await cameraSnapshot(
      http,
      url,
      login: const CameraLogin('admin', 'x'),
    );
    expect(image.first, 0xFF);
    await expectLater(
      cameraSnapshot(http, Uri.parse('http://$cam/index.html')),
      throwsA(isA<Object>()),
    );
    final d = cameraDevice(url, secured: true);
    expect(cameraUrl(d), url);
  });

  test(
    'SwitchBot Bot and Curtain: read from adverts, commands written',
    () async {
      BleAdvert sb(List<int> data) => BleAdvert(
        address: 'AA:BB:CC:DD:EE:01',
        serviceData: {0x0D00: Uint8List.fromList(data)},
      );
      final bot = parseAdvert(sb([0x48, 0x80, 90]))!;
      expect(
        (bot.model, bot.switchOn, bot.battery),
        ('SwitchBot Bot', true, 90),
      );
      expect(parseAdvert(sb([0x48, 0x00, 90]))!.switchOn, isNull);
      final curtain = parseAdvert(sb([0x63, 0x40, 77, 30]))!;
      expect((curtain.model, curtain.position), ('SwitchBot Curtain', 70));

      final scanner = FakeBleScanner();
      final backend = LocalBackend(
        [BleAdapter(scanner)],
        home: const LocalHome(
          devices: [
            ConfiguredDevice(
              adapter: 'ble',
              id: 'aabbccddee01',
              host: 'AA:BB:CC:DD:EE:01',
            ),
          ],
        ),
      )..start();
      addTearDown(backend.dispose);
      await pumpEventQueue();
      scanner.hear(sb([0x48, 0x80, 90]));
      await pumpEventQueue();
      final sw = backend.current.devices['ble:aabbccddee01:switch']!;
      expect(sw.state.isOn, isTrue);
      await backend.send(sw, const TurnOff());
      expect(scanner.writes.single, endsWith('570102'));
      expect(switchBotCommand('cover', const SetCoverPosition(25), sw.state), [
        0x57,
        0x0F,
        0x45,
        0x01,
        0x05,
        0xFF,
        75,
      ]);
    },
  );

  testWidgets('a camera added by its image address shows its image', (
    tester,
  ) async {
    final http = FakeLanRequests({
      'GET $cam/capture': (_) =>
          LanResponse(200, mockCameraFrame(0, DateTime(2026))),
    });
    await pumpApp(tester, size: const Size(800, 1600), requests: http);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 2);
    await tapKey(tester, 'addCamera');
    await settle(tester, 2);
    await tester.enterText(
      find.byKey(const Key('cameraUrl')),
      'http://$cam/capture',
    );
    await tapKey(tester, 'cameraOk');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 6);
    final added = container.read(localHomeProvider).devices.single;
    expect((added.adapter, added.options['snapshot']), ('camera', '/capture'));
    final id = '${added.key}:camera';
    expect(container.read(deviceProvider(id))?.kind, DeviceKind.camera);
    await goTo(tester, AppRoutes.device(id));
    await settle(tester, 4);
    expect(find.byKey(const Key('cameraImage')), findsOneWidget);
    expect(find.text(en.cameraOffline), findsNothing);
    await unmount(tester);
  });

  testWidgets('Broadlink found, a button learned on its screen, then sent', (
    tester,
  ) async {
    final device = FakeRm();
    final udp = FakeLanUdp({
      '255.255.255.255:80': device.handle,
      '$rm:80': device.handle,
    });
    await pumpApp(tester, size: const Size(800, 1600), udp: udp);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 6);
    await tapKey(tester, 'add-broadlink:665544332211');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 6);

    const remote = 'broadlink:665544332211:remote';
    await goTo(tester, AppRoutes.device(remote));
    await settle(tester, 4);
    expect(find.text(en.irButtonsEmpty), findsOneWidget);
    await tapKey(tester, 'irLearn');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('irLearnName')), 'TV on');
    await tapKey(tester, 'irLearnNameOk');
    await settle(tester, 2);
    expect(find.text(en.irLearnPress), findsOneWidget);
    // Heard on the second check, a second apart.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester, 6);
    expect(find.text(en.irLearned('TV on')), findsOneWidget);
    expect(
      container.read(localHomeProvider).devices.single.options['btn:TV on'],
      isNotNull,
    );
    await tapKey(tester, 'irButton-broadlink:665544332211:btn_tv_on');
    await settle(tester, 4);
    expect(device.sent.single, [0x26, 0x00, 0x10, 0x20]);
    await unmount(tester);
  });
}
