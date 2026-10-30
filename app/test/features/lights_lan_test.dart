import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/govee_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lan_transport.dart';
import 'package:open_smart_home_lite/features/devices/data/local/lifx_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/data/local/wiz_adapter.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../lan_fakes.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const wizBulb = '192.168.1.60';
const lifxBulb = '192.168.1.61';
const goveeStrip = '192.168.1.62';
const lifxMac = 'd073d5112233';

/// A WiZ RGB bulb, a LIFX bulb and a Govee strip, each keeping its state.
FakeLanUdp lightsNetwork() {
  final wiz = <String, Object?>{'state': false, 'dimming': 80, 'temp': 3000};
  var lifx = (hue: 0, sat: 0, bri: 0x8000, kelvin: 3500, power: 0xFFFF);
  final govee = <String, Object?>{
    'onOff': 1,
    'brightness': 40,
    'color': {'r': 255, 'g': 0, 'b': 0},
    'colorTemInKelvin': 0,
  };

  Uint8List lifxState() {
    final b = ByteData(52)
      ..setUint16(0, lifx.hue, Endian.little)
      ..setUint16(2, lifx.sat, Endian.little)
      ..setUint16(4, lifx.bri, Endian.little)
      ..setUint16(6, lifx.kelvin, Endian.little)
      ..setUint16(10, lifx.power, Endian.little);
    final out = b.buffer.asUint8List();
    final label = utf8.encode('Kuhinja');
    out.setRange(12, 12 + label.length, label);
    return out;
  }

  List<UdpPacket> lifxReply(int type, List<int> payload) {
    final p = lifxPacket(type, target: lifxMac, payload: payload);
    return [UdpPacket(lifxBulb, p)];
  }

  return FakeLanUdp({
    '255.255.255.255:38899': (_) => udpAnswer(wizBulb, {
      'method': 'registration',
      'result': {'mac': 'a8bb50aabbcc', 'success': true},
    }),
    '$wizBulb:38899': (data) {
      final m = jsonDecode(utf8.decode(data)) as Map;
      return switch (m['method']) {
        'getSystemConfig' => udpAnswer(wizBulb, {
          'result': {'mac': 'a8bb50aabbcc', 'moduleName': 'ESP01_SHRGB1C_31'},
        }),
        'getPilot' => udpAnswer(wizBulb, {'result': wiz}),
        'setPilot' => () {
          wiz.addAll((m['params'] as Map).cast<String, Object?>());
          return udpAnswer(wizBulb, {
            'result': {'success': true},
          });
        }(),
        _ => const [],
      };
    },
    '255.255.255.255:56700': (_) =>
        lifxReply(lifxStateService, [1, 0xBC, 0xDD, 0, 0]),
    '$lifxBulb:56700': (data) {
      final m = lifxParse(data)!;
      final p = ByteData.sublistView(m.payload);
      if (m.type == lifxSetPower) {
        lifx = (
          hue: lifx.hue,
          sat: lifx.sat,
          bri: lifx.bri,
          kelvin: lifx.kelvin,
          power: p.getUint16(0, Endian.little),
        );
      } else if (m.type == lifxSetColor) {
        lifx = (
          hue: p.getUint16(1, Endian.little),
          sat: p.getUint16(3, Endian.little),
          bri: p.getUint16(5, Endian.little),
          kelvin: p.getUint16(7, Endian.little),
          power: lifx.power,
        );
      }
      return lifxReply(lifxLightState, lifxState());
    },
    '239.255.255.250:4001': (_) => udpAnswer(goveeStrip, {
      'msg': {
        'cmd': 'scan',
        'data': {
          'ip': goveeStrip,
          'device': '1F:80:C5:32:32:36:72:4E',
          'sku': 'H6159',
        },
      },
    }),
    '$goveeStrip:4003': (data) {
      final msg = (jsonDecode(utf8.decode(data)) as Map)['msg'] as Map;
      final d = msg['data'] as Map;
      switch (msg['cmd']) {
        case 'turn':
          govee['onOff'] = d['value'];
        case 'brightness':
          govee['brightness'] = d['value'];
        case 'colorwc':
          govee['color'] = d['color'];
          govee['colorTemInKelvin'] = d['colorTemInKelvin'];
        case 'devStatus':
          return udpAnswer(goveeStrip, {
            'msg': {'cmd': 'devStatus', 'data': govee},
          });
      }
      return const [];
    },
  });
}

LocalBackend backendOf(FakeLanUdp udp, List<ConfiguredDevice> devices) =>
    LocalBackend([
      WizAdapter(udp),
      LifxAdapter(udp),
      GoveeAdapter(udp),
    ], home: LocalHome(devices: devices, demo: false));

void main() {
  test('WiZ: colour bulb read, turned on, dimmed, coloured', () async {
    final udp = lightsNetwork();
    final backend = backendOf(udp, const [
      ConfiguredDevice(
        adapter: 'wiz',
        id: 'a8bb50aabbcc',
        host: wizBulb,
        model: 'ESP01_SHRGB1C_31',
        label: 'Lampa',
      ),
    ])..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    const id = 'wiz:a8bb50aabbcc:light';
    var bulb = backend.current.devices[id]!;
    expect(bulb.kind, DeviceKind.rgbLight);
    expect(bulb.state.isOn, isFalse);

    await backend.send(bulb, const SetBrightness(5));

    await pumpEventQueue();
    bulb = backend.current.devices[id]!;
    expect(bulb.state.brightnessPercent, 10, reason: 'WiZ dims to 10 %');
    await backend.send(bulb, const SetRgbColor(RgbColor(0, 0, 255)));
    await pumpEventQueue();
    expect(udp.textsTo('$wizBulb:38899'), contains(contains('"b":255')));
    expect(wizModule('ESP10_SOCKET_06').plug, isTrue);
  });

  test('LIFX: header and state, white and colour', () async {
    final packet = lifxPacket(lifxLightGet, target: lifxMac, sequence: 7);
    final m = lifxParse(packet)!;
    expect((m.type, m.mac, packet.length), (lifxLightGet, lifxMac, 36));

    final udp = lightsNetwork();
    final backend = backendOf(udp, const [
      ConfiguredDevice(adapter: 'lifx', id: lifxMac, host: lifxBulb),
    ])..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    const id = 'lifx:$lifxMac:light';
    var bulb = backend.current.devices[id]!;
    expect(bulb.name, 'Kuhinja');
    expect(bulb.state.brightnessPercent, 50);
    expect(bulb.state.colorTemperatureKelvin, 3500);

    await backend.send(bulb, const SetRgbColor(RgbColor(255, 0, 0)));

    await pumpEventQueue();
    await backend.refresh();
    await pumpEventQueue();
    bulb = backend.current.devices[id]!;
    expect(bulb.state.rgb, const RgbColor(255, 0, 0));
    await backend.send(bulb, const TurnOff());
    await pumpEventQueue();
    await backend.refresh();
    await pumpEventQueue();
    expect(backend.current.devices[id]!.state.isOn, isFalse);
  });

  test('Govee: status, brightness turns on first', () async {
    final udp = lightsNetwork();
    final backend = backendOf(udp, const [
      ConfiguredDevice(
        adapter: 'govee',
        id: '1f80c5323236724e',
        host: goveeStrip,
      ),
    ])..start();
    addTearDown(backend.dispose);
    await pumpEventQueue();
    const id = 'govee:1f80c5323236724e:light';
    var strip = backend.current.devices[id]!;
    expect(strip.state.rgb, const RgbColor(255, 0, 0));
    await backend.send(strip, const TurnOff());
    await pumpEventQueue();
    strip = backend.current.devices[id]!;
    expect(strip.state.isOn, isFalse);
    await backend.send(strip, const SetBrightness(70));
    await pumpEventQueue();
    final sent = udp.textsTo('$goveeStrip:4003');
    expect(sent[sent.length - 3], contains('"turn"'));
    expect(sent[sent.length - 2], contains('"brightness"'));
  });

  testWidgets('WiZ, LIFX and Govee found by their own search; WiZ added', (
    tester,
  ) async {
    final udp = lightsNetwork();
    await pumpApp(tester, size: const Size(800, 1600), udp: udp);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 6);
    expect(find.byKey(const ValueKey('add-wiz:a8bb50aabbcc')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-lifx:$lifxMac')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-govee:1f80c5323236724e')),
      findsOneWidget,
    );
    await tapKey(tester, 'add-wiz:a8bb50aabbcc');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 6);
    expect(find.text(en.addDeviceAdded), findsWidgets);
    const id = 'wiz:a8bb50aabbcc:light';
    expect(container.read(deviceProvider(id))!.state.isOn, isFalse);
    await goTo(tester, AppRoutes.device(id));
    await tapKey(tester, 'powerSwitch');
    await settle(tester, 4);
    expect(container.read(deviceProvider(id))!.state.isOn, isTrue);
    await unmount(tester);
  });
}
