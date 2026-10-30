import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/security/pin_hasher.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';

import '../helpers.dart';

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PinHasher', () {
    test('PBKDF2-HMAC-SHA256 matches the RFC 7914 test vector', () {
      final dk = base64Decode(
        PinHasher.hash('passwd', base64Encode(utf8.encode('salt')), rounds: 1),
      );
      expect(
        hex(dk),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });

    test('verify accepts only the right PIN', () {
      final salt = PinHasher.newSalt();
      final hash = PinHasher.hash('2468', salt, rounds: 100);
      expect(PinHasher.verify('2468', salt, hash, rounds: 100), isTrue);
      expect(PinHasher.verify('2469', salt, hash, rounds: 100), isFalse);
    });

    test('same PIN with different salts gives different hashes', () {
      expect(
        PinHasher.hash('1234', PinHasher.newSalt(), rounds: 10),
        isNot(PinHasher.hash('1234', PinHasher.newSalt(), rounds: 10)),
      );
    });

    test('PIN format', () {
      expect(PinHasher.validPin.hasMatch('1234'), isTrue);
      expect(PinHasher.validPin.hasMatch('12345678'), isTrue);
      expect(PinHasher.validPin.hasMatch('123'), isFalse);
      expect(PinHasher.validPin.hasMatch('12a4'), isFalse);
    });
  });

  test('KioskSettings JSON round-trip and defaults', () {
    const s = KioskSettings(
      startInKiosk: true,
      dimAfter: Duration.zero,
      pinHash: 'h',
      pinSalt: 's',
      quickControls: ['fx:light.hallway', 'group:d_coffee'],
      homeCards: [HomeCard.floorPlan, HomeCard.weather],
    );
    final back = KioskSettings.fromJson(s.toJson());
    expect(back.quickControls, ['fx:light.hallway', 'group:d_coffee']);
    expect(back.homeCards, [HomeCard.floorPlan, HomeCard.weather]);
    // Settings of the old looks are simply ignored.
    expect(
      KioskSettings.fromJson({
        'style': 'bubble',
        'background': 'dusk',
        'pages': [{}],
      }).homeCards,
      HomeCard.values,
    );
    expect(back.startInKiosk, isTrue);
    expect(back.dimAfter, Duration.zero);
    expect(back.hasPin, isTrue);
    expect(KioskSettings.fromJson(null).keepScreenOn, isTrue);
    expect(
      KioskSettings.fromJson({'dimAfterSeconds': 'x'}).dimAfter,
      const KioskSettings().dimAfter,
    );
  });

  group('KioskSessionController', () {
    late ProviderContainer c;

    setUp(() async {
      c = ProviderContainer(
        overrides: await testOverrides(),
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
    });

    test('without a PIN anyone can exit', () async {
      c.read(kioskActiveProvider.notifier).enter();
      expect(
        await c.read(kioskActiveProvider.notifier).tryExit(''),
        PinCheck.accepted,
      );
      expect(c.read(kioskActiveProvider), isFalse);
    });

    test('wrong PINs lock out after 5 attempts, then expire', () async {
      await c.read(kioskSettingsProvider.notifier).setPin('1357');
      final kiosk = c.read(kioskActiveProvider.notifier)..enter();
      var now = DateTime(2026, 10, 13, 12);
      kiosk.now = () => now;

      for (var i = 0; i < 4; i++) {
        expect(await kiosk.tryExit('0000'), PinCheck.wrong);
      }
      expect(await kiosk.tryExit('0000'), PinCheck.lockedOut);
      expect(
        await kiosk.tryExit('1357'),
        PinCheck.lockedOut,
        reason: 'even the right PIN waits',
      );
      expect(c.read(kioskActiveProvider), isTrue);

      now = now.add(
        KioskSessionController.lockout + const Duration(seconds: 1),
      );
      expect(await kiosk.tryExit('1357'), PinCheck.accepted);
      expect(c.read(kioskActiveProvider), isFalse);
    });

    test('invalid PIN format is rejected when setting', () async {
      expect(
        await c.read(kioskSettingsProvider.notifier).setPin('12'),
        isFalse,
      );
      expect(c.read(kioskSettingsProvider).hasPin, isFalse);
    });

    test('PIN is stored only as salted hash', () async {
      await c.read(kioskSettingsProvider.notifier).setPin('97531');
      final json = c.read(kioskSettingsProvider).toJson().toString();
      expect(json, isNot(contains('97531')));
    });
  });

  group('router redirects in kiosk mode', () {
    String? r(String location, {bool kiosk = true}) =>
        resolveRedirect(location: location, kioskActive: kiosk);

    test('everything outside kiosk routes is redirected into kiosk', () {
      expect(r(AppRoutes.settings), AppRoutes.kiosk);
      expect(r(AppRoutes.device('fx:light.x')), AppRoutes.kiosk);
      expect(r(AppRoutes.addDevice), AppRoutes.kiosk);
      expect(r(AppRoutes.kiosk), isNull);
      expect(r(AppRoutes.device('fx:light.x', kiosk: true)), isNull);
      expect(r(AppRoutes.room('living_room', kiosk: true)), isNull);
    });

    test('kiosk routes are closed when kiosk mode is off', () {
      expect(r(AppRoutes.kiosk, kiosk: false), AppRoutes.home);
      expect(
        r('/kioskfoo', kiosk: false),
        isNull,
        reason: 'prefix must be a path segment',
      );
    });
  });
}
