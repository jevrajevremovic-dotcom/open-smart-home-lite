import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/dirigera_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/klap.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/tapo_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';

import '../lan_fakes.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const hub = '192.168.1.90';
const plug = '192.168.1.91';
const account = TpLinkAccount('ana@example.com', 'tajna');

List<int> _sha(List<int> b) => hash.sha256.convert(b).bytes;

/// A Tapo P110 speaking KLAP v2 for [owner]: the device side of the
/// handshake, then requests decrypted, answered and encrypted back.
Map<String, FutureOr<LanResponse> Function(FakeRequest)> tapoDevice(
  String host,
  TpLinkAccount owner,
) {
  final remote = List<int>.generate(16, (i) => 200 - i);
  final auth = klapAuthHash(owner, 2);
  late List<int> local;
  var session = 0;
  var on = false;
  final aes = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
  return {
    'POST $host/app/handshake1': (r) {
      local = r.body;
      // One session at a time: a new handshake ends the one before.
      session++;
      return LanResponse(
        200,
        Uint8List.fromList([
          ...remote,
          ..._sha([...local, ...remote, ...auth]),
        ]),
        headers: {'set-cookie': 'TP_SESSIONID=s$session;TIMEOUT=86400'},
      );
    },
    'POST $host/app/handshake2': (r) {
      final ok = listEquals(r.body, _sha([...remote, ...local, ...auth]));
      return LanResponse(ok ? 200 : 403, Uint8List(0));
    },
    'POST $host/app/request': (r) async {
      if (r.headers['cookie'] != 'TP_SESSIONID=s$session') {
        return LanResponse(403, Uint8List(0));
      }
      final seed = [...local, ...remote, ...auth];
      final key = _sha([...utf8.encode('lsk'), ...seed]).sublist(0, 16);
      final iv = _sha([...utf8.encode('iv'), ...seed]).sublist(0, 12);
      final seq = int.parse(r.uri.queryParameters['seq']!);
      final seqBytes = (ByteData(4)..setInt32(0, seq)).buffer.asUint8List();
      final nonce = [...iv, ...seqBytes];
      final secret = SecretKey(key);
      final clear = await aes.decrypt(
        SecretBox(r.body.sublist(32), nonce: nonce, mac: Mac.empty),
        secretKey: secret,
      );
      final req = jsonDecode(utf8.decode(clear)) as Map;
      final result = switch (req['method']) {
        'get_device_info' => {
          'device_id': '80224F00',
          'model': 'P110',
          'type': 'SMART.TAPOPLUG',
          'mac': 'AC-15-A2-00-11-22',
          'nickname': base64.encode(utf8.encode('Bojler')),
          'device_on': on,
        },
        'get_current_power' => {'current_power': 1850},
        'set_device_info' => () {
          on = (req['params'] as Map)['device_on'] as bool;
          return <String, Object?>{};
        }(),
        _ => null,
      };
      final box = await aes.encrypt(
        utf8.encode(
          jsonEncode(
            result == null
                ? {'error_code': -1}
                : {'error_code': 0, 'result': result},
          ),
        ),
        secretKey: secret,
        nonce: nonce,
      );
      return LanResponse(
        200,
        Uint8List.fromList([...List.filled(32, 0), ...box.cipherText]),
      );
    },
  };
}

/// A hub that gives its token after the button was "pressed" on the
/// [pressedAfter]th try, with a lamp, a blind and an air sensor.
Map<String, LanResponse Function(FakeRequest)> dirigeraHub({
  int pressedAfter = 1,
}) {
  var tries = 0;
  var lampOn = false;
  return {
    'GET $hub:8443/v1/oauth/authorize': (r) {
      expect(r.uri.queryParameters['code_challenge_method'], 'S256');
      return jsonResponse({'code': 'c1'});
    },
    'POST $hub:8443/v1/oauth/token': (r) {
      expect(Uri.splitQueryString(r.text)['code'], 'c1');
      return ++tries > pressedAfter
          ? jsonResponse({'access_token': 'hubtok'})
          : jsonResponse({'error': 'no button'}, status: 403);
    },
    'GET $hub:8443/v1/devices': (r) {
      if (r.headers['authorization'] != 'Bearer hubtok') {
        return textResponse('', status: 401);
      }
      return jsonResponse([
        {'id': 'gw', 'deviceType': 'gateway', 'attributes': {}},
        {
          'id': 'lamp1',
          'deviceType': 'light',
          'isReachable': true,
          'capabilities': {
            'canReceive': ['isOn', 'lightLevel', 'colorTemperature'],
          },
          'attributes': {
            'customName': 'Stona lampa',
            'isOn': lampOn,
            'lightLevel': 40,
            'colorTemperature': 2700,
            'colorTemperatureMin': 4000,
            'colorTemperatureMax': 2202,
            'colorMode': 'temperature',
          },
        },
        {
          'id': 'blind1',
          'deviceType': 'blinds',
          'attributes': {'customName': 'Roletna', 'blindsCurrentLevel': 30},
        },
        {
          'id': 'air1',
          'deviceType': 'environmentSensor',
          'attributes': {
            'customName': 'Vazduh',
            'currentTemperature': 21.5,
            'currentRH': 44,
            'batteryPercentage': 80,
          },
        },
      ]);
    },
    'PATCH $hub:8443/v1/devices/lamp1': (r) {
      final change = (r.json! as List).first as Map<String, Object?>;
      lampOn = (change['attributes']! as Map)['isOn'] == true;
      return textResponse('', status: 202);
    },
    'PATCH $hub:8443/v1/devices/blind1': (_) => textResponse('', status: 202),
  };
}

void main() {
  test('PKCE challenge is base64url SHA-256 without padding', () {
    // RFC 7636, appendix B.
    expect(
      DirigeraPairing.challenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test(
    'DIRIGERA: paired with its button; lamp, blind, sensor; commands',
    () async {
      final http = FakeLanRequests(dirigeraHub());
      final pairing = DirigeraPairing(http, hub);
      expect(await pairing.tryLink(), isNull, reason: 'button not pressed yet');
      expect(await pairing.tryLink(), 'hubtok');
      expect(
        http.requests.where((r) => r.uri.path == '/v1/oauth/authorize'),
        hasLength(1),
        reason: 'one code for all tries',
      );

      final backend = LocalBackend(
        [DirigeraAdapter(http, tokens: (_) async => 'hubtok')],
        home: const LocalHome(
          devices: [ConfiguredDevice(adapter: 'dirigera', id: 'h1', host: hub)],
        ),
      )..start();
      addTearDown(backend.dispose);
      await pumpEventQueue();
      final d = backend.current.devices;
      final lamp = d['dirigera:h1:lamp1:light']!;
      expect(lamp.kind, DeviceKind.dimmableLight);
      expect(
        (
          lamp.limits.minColorTemperatureKelvin,
          lamp.limits.maxColorTemperatureKelvin,
        ),
        (2202, 4000),
      );
      expect(d['dirigera:h1:blind1:cover']!.state.position, 70);
      expect(d['dirigera:h1:air1:temperature']!.state.currentTemperature, 21.5);
      expect(d['dirigera:h1:air1:humidity']!.metadata.batteryPercent, 80);
      expect(d.keys.where((k) => k.contains(':gw:')), isEmpty);

      await backend.send(lamp, const TurnOn());
      await pumpEventQueue();
      expect(
        backend.current.devices['dirigera:h1:lamp1:light']!.state.isOn,
        isTrue,
      );
      await backend.send(
        d['dirigera:h1:blind1:cover']!,
        const SetCoverPosition(25),
      );
      final patch = http.requests.lastWhere((r) => r.method == 'PATCH');
      expect(patch.json, [
        {
          'attributes': {'blindsTargetLevel': 75},
        },
      ]);
    },
  );

  test('KLAP: the handshake proves the account; requests round-trip', () async {
    final http = FakeLanRequests(tapoDevice(plug, account));
    final klap = KlapClient(http);
    final id = await tapoIdentify(klap, plug, account);
    expect((id?.id, id?.name, id?.model), ('ac15a2001122', 'Bojler', 'P110'));
    await expectLater(
      tapoIdentify(KlapClient(http), plug, const TpLinkAccount('x', 'y')),
      throwsA(isA<Object>()),
    );

    final backend = LocalBackend(
      [TapoAdapter(klap, accounts: (_) async => account.encode())],
      home: const LocalHome(
        devices: [
          ConfiguredDevice(adapter: 'tapo', id: 'ac15a2001122', host: plug),
        ],
      ),
    )..start();
    addTearDown(backend.dispose);
    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 100 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    await until(
      () => backend.current.devices.containsKey('tapo:ac15a2001122:power'),
    );
    final p = backend.current.devices['tapo:ac15a2001122:switch']!;
    expect(
      (p.name, p.kind, p.state.isOn),
      ('Bojler', DeviceKind.outlet, false),
    );
    expect(
      backend.current.devices['tapo:ac15a2001122:power']!.state.numericValue,
      1850,
    );
    await backend.send(p, const TurnOn());
    await until(
      () =>
          backend.current.devices['tapo:ac15a2001122:switch']!.state.isOn ==
          true,
    );
    expect(
      backend.current.devices['tapo:ac15a2001122:switch']!.state.isOn,
      isTrue,
    );
  });

  testWidgets(
    'Tapo added by its address: wrong account refused, right one added',
    (tester) async {
      final credentials = await pumpApp(
        tester,
        size: const Size(800, 1600),
        requests: FakeLanRequests(tapoDevice(plug, account)),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SmartHomeApp)),
      );
      await goTo(tester, AppRoutes.addDevice);
      await settle(tester, 2);

      Future<void> add(String user, String password) async {
        await tapKey(tester, 'addDeviceManual');
        await settle(tester, 2);
        await tester.enterText(find.byKey(const Key('addDeviceAddress')), plug);
        await tapKey(tester, 'addDeviceAddressOk');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await settle(tester, 4);
        expect(find.text(en.tpLinkAccountHint), findsOneWidget);
        await tester.enterText(find.byKey(const Key('addDeviceUser')), user);
        await tester.enterText(
          find.byKey(const Key('addDevicePassword')),
          password,
        );
        await tapKey(tester, 'addDeviceConfirm');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await settle(tester, 6);
      }

      await add('ana@example.com', 'pogresna');
      expect(find.text(en.tpLinkWrongAccount), findsOneWidget);
      expect(container.read(localHomeProvider).devices, isEmpty);

      await add('ana@example.com', 'tajna');
      final added = container.read(localHomeProvider).devices.single;
      expect((added.adapter, added.id), ('tapo', 'ac15a2001122'));
      expect(
        TpLinkAccount.decode(credentials.values['device:tapo:ac15a2001122'])
            ?.user,
        'ana@example.com',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await settle(tester, 4);
      expect(
        container.read(deviceProvider('tapo:ac15a2001122:switch'))?.name,
        'Bojler',
      );
      await unmount(tester);
    },
  );
}
