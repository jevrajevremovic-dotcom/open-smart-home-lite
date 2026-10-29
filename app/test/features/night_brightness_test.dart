import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/data/kiosk_settings.dart';

import '../helpers.dart' show FakeKioskPlatform;
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

DateTime at(int h, int m) => DateTime(2026, 10, 15, h, m);

void main() {
  test('night window, also across midnight', () {
    const s = KioskSettings(nightBrightness: true, nightLevel: 0.2);
    expect(s.brightnessAt(at(23, 30), dimmed: false), 0.2);
    expect(s.brightnessAt(at(3, 0), dimmed: false), 0.2);
    expect(s.brightnessAt(at(7, 0), dimmed: false), isNull);
    expect(s.brightnessAt(at(12, 0), dimmed: false), isNull);
    expect(
      s.brightnessAt(at(12, 0), dimmed: true),
      0.4,
      reason: 'always-on screen: readable, not glaring',
    );
    expect(
      s.brightnessAt(at(23, 30), dimmed: true),
      0.2,
      reason: 'at night the darker of the two',
    );
    expect(
      const KioskSettings(aodBrightness: 0.7)
          .brightnessAt(at(12, 0), dimmed: true),
      0.7,
    );
    const day = KioskSettings(
      nightBrightness: true,
      nightFrom: 13 * 60,
      nightTo: 15 * 60,
    );
    expect(day.isNight(at(14, 0)), isTrue);
    expect(day.isNight(at(15, 0)), isFalse);
    const off = KioskSettings(darkScreensaver: false);
    expect(off.brightnessAt(at(23, 0), dimmed: true), isNull);
  });

  testWidgets('screensaver turns the backlight down; leaving restores it', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1280, 800));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final platform = container.read(kioskPlatformProvider) as FakeKioskPlatform;
    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(dimAfter: const Duration(seconds: 30)));

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    await tester.pump(const Duration(seconds: 31));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskScreensaver')), findsOneWidget);
    expect(platform.brightness, 0.4);

    await tester.tap(find.byKey(const Key('kioskScreensaver')));
    await settle(tester, 2);
    expect(platform.brightness, isNull);

    // Always "night" for this test.
    await container
        .read(kioskSettingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            nightBrightness: true,
            nightFrom: 0,
            nightTo: 24 * 60 - 1,
            nightLevel: 0.3,
          ),
        );
    await settle(tester, 2);
    expect(platform.brightness, 0.3);

    await tester.tap(find.byKey(const Key('kioskExit')));
    await settle(tester, 6);
    expect(platform.brightness, isNull, reason: 'system brightness again');
    await unmount(tester);
  });
}
