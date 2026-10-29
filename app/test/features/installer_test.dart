import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/app_info.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/logging/app_logger.dart';
import 'package:open_smart_home_lite/features/ha_notify/ha_push.dart';
import 'package:open_smart_home_lite/features/kiosk/application/device_admin.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

class _FakeAdmin implements DeviceAdminPlatform {
  _FakeAdmin({this.owner = false});

  bool owner;
  final calls = <String>[];

  @override
  Future<DeviceInfo> info() async => DeviceInfo(
    manufacturer: 'samsung',
    model: 'SM-T505',
    android: '12',
    sdk: 31,
    package: 'org.opensmarthome.open_smart_home',
    deviceOwner: owner,
  );

  @override
  Future<bool> lockTask(bool on) async {
    calls.add('lock:$on');
    return owner;
  }

  @override
  Future<bool> applyPolicies() async {
    calls.add('policies');
    return owner;
  }

  @override
  Future<bool> release() async {
    calls.add('release');
    owner = false;
    return true;
  }
}

void main() {
  test('app version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $appVersion+'));
  });

  testWidgets('service screen: device, server, problems; copy has no token', (
    tester,
  ) async {
    final admin = _FakeAdmin(owner: true);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      overrides: [deviceAdminProvider.overrideWithValue(admin)],
    );
    await settle(tester, 10);
    AppLogger('Test').warning('something odd');
    await goTo(tester, AppRoutes.settingsSection('service'));
    await settle(tester, 4);
    expect(find.textContaining('SM-T505'), findsOneWidget);
    expect(find.text(en.servicePanelManaged), findsOneWidget);
    expect(find.textContaining('something odd'), findsOneWidget);

    await tapKey(tester, 'servicePanelApply');
    await settle(tester, 2);
    expect(admin.calls, contains('policies'));

    await tapKey(tester, 'serviceCopy');
    await settle(tester, 2);
    expect(copied, contains('SM-T505'));
    expect(copied, contains('homeassistant.local'));
    expect(copied, isNot(contains('token')));
    expect(copied, isNot(contains('8123')), reason: 'host only');

    await tapKey(tester, 'servicePanelRelease');
    await settle(tester, 2);
    await tapKey(tester, 'servicePanelReleaseConfirm');
    await settle(tester, 4);
    expect(admin.calls, contains('release'));
    expect(find.text(en.servicePanelNot), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('setup wizard: messages, kiosk PIN, then into the locked kiosk', (
    tester,
  ) async {
    final admin = _FakeAdmin(owner: true);
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      overrides: [deviceAdminProvider.overrideWithValue(admin)],
    );
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    await goTo(tester, AppRoutes.installerSetup);
    await settle(tester, 4);
    expect(find.textContaining('homeassistant.local'), findsOneWidget);
    await tapKey(tester, 'setupNext-0');
    await settle(tester, 2);
    await tapKey(tester, 'setupNext-1');
    await settle(tester, 2);
    await tapKey(tester, 'setupRegister');
    await settle(tester, 6);
    expect(
      container.read(haPushProvider).value?.deviceName,
      en.setupDefaultDeviceName,
    );
    await tapKey(tester, 'setupNext-2');
    await settle(tester, 2);
    await tapKey(tester, 'setupStartInKiosk');
    await tester.enterText(find.byKey(const Key('setupPin')), '12');
    await tapKey(tester, 'setupPinSave');
    await settle(tester, 2);
    expect(find.text(en.kioskPinInvalid), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setupPin')), '2468');
    await tapKey(tester, 'setupPinSave');
    await settle(tester, 2);
    final kiosk = container.read(kioskSettingsProvider);
    expect(kiosk.hasPin, isTrue);
    expect(kiosk.startInKiosk, isTrue);
    await tapKey(tester, 'setupNext-3');
    await settle(tester, 2);
    await tapKey(tester, 'setupNext-4');
    await settle(tester, 2);
    await tapKey(tester, 'setupStartKiosk');
    await settle(tester, 8);
    expect(container.read(kioskActiveProvider), isTrue);
    // A managed panel locks the kiosk for real.
    expect(admin.calls, contains('lock:true'));
    await unmount(tester);
  });
}
