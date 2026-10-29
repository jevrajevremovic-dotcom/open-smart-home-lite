import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/application/device_providers.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_adapter.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_advert.dart';
import 'package:open_smart_home_lite/features/devices/data/local/ble/ble_scanner.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_backend.dart';
import 'package:open_smart_home_lite/features/devices/data/local/local_home.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';

import '../helpers.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

const mac = 'A4:C1:38:12:34:56';
Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

BleAdvert service(int uuid, List<int> data, {String? name}) => BleAdvert(
  address: mac,
  name: name,
  rssi: -60,
  serviceData: {uuid: b(data)},
);

void main() {
  group('formats', () {
    test('BTHome v2 (the example on bthome.io)', () {
      final r = parseAdvert(
        service(0xFCD2, [0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13]),
      )!;
      expect((r.model, r.temperature, r.humidity), ('BTHome', 25.06, 50.55));
    });

    test('BTHome: a Shelly BLU Door/Window (window, light, battery)', () {
      final r = parseAdvert(
        service(0xFCD2, [
          0x44, // v2, trigger based
          0x00, 0x21, // packet id
          0x01, 0x64, // battery 100 %
          0x05, 0x10, 0x27, 0x00, // illuminance 100.00 lx
          0x2D, 0x01, // window open
          0x3F, 0x00, 0x00, // rotation (read past)
        ]),
      )!;
      expect(
        (r.battery, r.illuminance, r.open, r.packetId),
        (100, 100.0, true, 0x21),
      );
    });

    test(
      'BTHome: encrypted is left alone; an unknown object keeps the rest',
      () {
        expect(parseAdvert(service(0xFCD2, [0x41, 0x02, 0xCA, 0x09])), isNull);
        final r = parseAdvert(
          service(0xFCD2, [0x40, 0x01, 0x50, 0xEE, 0x01, 0x02]),
        )!;
        expect((r.battery, r.temperature), (80, null));
      },
    );

    test('pvvx and ATC firmware (Xiaomi LYWSD03MMC)', () {
      final pvvx = parseAdvert(
        service(0x181A, [
          0x56, 0x34, 0x12, 0x38, 0xC1, 0xA4, // MAC, little endian
          0x69, 0x08, // 21.53 °C
          0xF2, 0x12, // 48.50 %
          0x86, 0x0B, // 2950 mV
          87, // battery
          5, 0x04, // counter, flags
        ]),
      )!;
      expect(
        (pvvx.temperature, pvvx.humidity, pvvx.battery),
        (21.53, 48.5, 87),
      );
      final atc = parseAdvert(
        service(0x181A, [
          0xA4, 0xC1, 0x38, 0x12, 0x34, 0x56, // MAC
          0xFF, 0xF6, // -1.0 °C
          60, 90, // humidity, battery
          0x0B, 0x54, // 2900 mV
          7, // counter
        ]),
      )!;
      expect(
        (atc.model, atc.temperature, atc.humidity, atc.battery),
        ('LYWSD03MMC (ATC)', -1.0, 60.0, 90),
      );
    });

    test('SwitchBot Meter and Govee', () {
      final bot = parseAdvert(
        service(0xFD3D, [0x54, 0x00, 0x64, 0x05, 0x95, 0x30]),
      )!;
      expect((bot.temperature, bot.humidity, bot.battery), (21.5, 48.0, 100));

      BleAdvert govee(List<int> data) =>
          BleAdvert(address: mac, manufacturerData: {0xEC88: b(data)});
      // 21.5 °C, 48.5 % → 215485 = 0x0349BD.
      final warm = parseAdvert(govee([0x00, 0x03, 0x49, 0xBD, 87, 0x00]))!;
      expect((warm.temperature, warm.humidity, warm.battery), (21.5, 48.5, 87));
      // -5.2 °C, 60.0 % → 52600 = 0x00CD78, with the sign bit.
      final cold = parseAdvert(govee([0x00, 0x80, 0xCD, 0x78, 50, 0x00]))!;
      expect((cold.temperature, cold.humidity), (-5.2, 60.0));
    });

    test('what Android sends becomes an advertisement', () {
      final a = advertFromPlatform({
        'address': mac,
        'name': 'ATC_123456',
        'rssi': -71,
        'serviceData': {
          '0000fcd2-0000-1000-8000-00805f9b34fb': b([0x40, 0x01, 0x10]),
        },
        'manufacturerData': {
          0xEC88: b([1, 2, 3]),
        },
      })!;
      expect(a.id, 'a4c138123456');
      expect(a.serviceData.keys, [0xFCD2]);
      expect(a.manufacturerData.keys, [0xEC88]);
    });
  });

  test(
    'the adapter: values of added sensors only; stale after hours',
    () async {
      final scanner = FakeBleScanner();
      var now = DateTime(2026, 10, 29, 12);
      final backend = LocalBackend(
        [BleAdapter(scanner, clock: () => now)],
        home: const LocalHome(
          demo: false,
          devices: [
            ConfiguredDevice(
              adapter: 'ble',
              id: 'a4c138123456',
              host: mac,
              label: 'Spavaća',
            ),
          ],
        ),
      )..start();
      addTearDown(backend.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(
        backend.current.devices['ble:a4c138123456:device']!.available,
        isFalse,
        reason: 'not heard yet',
      );

      scanner
        ..hear(service(0xFCD2, [0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13]))
        ..hear(
          BleAdvert(
            address: 'A4:C1:38:00:00:00', // not added
            serviceData: {
              0xFCD2: b([0x40, 0x02, 0x00, 0x00]),
            },
          ),
        )
        ..hear(service(0xFCD2, [0x40, 0x01, 0x5A])); // battery alone, later
      await Future<void>.delayed(Duration.zero);
      final d = backend.current.devices;
      final t = d['ble:a4c138123456:temperature']!;
      expect(
        (t.name, t.state.currentTemperature, t.available),
        ('Spavaća', 25.06, true),
      );
      expect(t.protocol, DeviceProtocol.bluetooth);
      expect(t.metadata.batteryPercent, 90, reason: 'merged from the next one');
      expect(d['ble:a4c138123456:humidity']!.name, 'Spavaća · %');
      expect(d.keys.where((k) => k.contains('a4c138000000')), isEmpty);

      now = now.add(const Duration(hours: 4));
      scanner.hear(service(0xFCD2, [0x40, 0x99, 0x00])); // unknown: not heard
      backend.configure(backend.home); // re-publish
      await Future<void>.delayed(Duration.zero);
      expect(
        backend.current.devices['ble:a4c138123456:temperature']!.available,
        isFalse,
      );
    },
  );

  testWidgets('add a thermometer heard nearby, after allowing Bluetooth', (
    tester,
  ) async {
    final scanner = FakeBleScanner(permitted: false);
    await pumpApp(
      tester,
      size: const Size(800, 1800),
      http: FakeLanHttp(const {}),
      ble: scanner,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 3);
    expect(find.text(en.blePermissionHint), findsOneWidget);
    await tapKey(tester, 'blePermission');
    await settle(tester, 3);
    expect(scanner.asked, 1);
    expect(find.text(en.bleNoneYet), findsOneWidget);

    scanner.hear(
      service(0xFCD2, [
        0x40, 0x02, 0xCA, 0x09, 0x03, 0xBF, 0x13, 0x01, 0x5A, //
      ], name: 'ATC_123456'),
    );
    await settle(tester, 3);
    expect(find.text('ATC_123456'), findsOneWidget);
    expect(find.textContaining('25.1 °C · 51 % · 🔋 90 %'), findsOneWidget);

    await tapKey(tester, 'add-ble:a4c138123456');
    await settle(tester, 3);
    await tapKey(tester, 'addDeviceConfirm');
    await settle(tester, 4);
    scanner.hear(service(0xFCD2, [0x40, 0x00, 0x02, 0x02, 0xCA, 0x09]));
    await settle(tester, 3);
    final t = container.read(deviceProvider('ble:a4c138123456:temperature'))!;
    expect(
      (t.kind, t.state.currentTemperature),
      (DeviceKind.temperatureSensor, 25.06),
    );
    await unmount(tester);
  });
}
