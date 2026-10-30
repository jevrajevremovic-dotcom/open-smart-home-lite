import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/restricted/application/restricted_mode.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('hidden kinds follow the options; off hides nothing', () {
    const on = RestrictedSettings(enabled: true, hideCameras: false);
    expect(on.hiddenKinds, contains(DeviceKind.lock));
    expect(on.hiddenKinds, isNot(contains(DeviceKind.camera)));
    expect(const RestrictedSettings().hiddenKinds, isEmpty);
    expect(
      RestrictedSettings.fromJson({'enabled': true}).enabled,
      isFalse,
      reason: 'never on without a PIN',
    );
  });

  test('router keeps children out of adding devices', () {
    expect(
      resolveRedirect(location: AppRoutes.addDevice, restricted: true),
      AppRoutes.home,
    );
  });

  testWidgets('turn on with a PIN, devices hidden, settings closed, PIN off', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('security'));
    await tapKey(tester, 'restrictedSettings');
    await settle(tester, 4);
    await tapKey(tester, 'restrictedEnable');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pinField')), '2468');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 4);
    await tester.enterText(find.byKey(const Key('pinField')), '2468');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);

    // Settings are closed; the lock is hidden.
    await goTo(tester, AppRoutes.settingsSection('security'));
    await settle(tester, 2);
    expect(find.byKey(const Key('restrictedActive')), findsOneWidget);
    expect(find.text(en.addDeviceTitle), findsNothing);
    await goTo(tester, AppRoutes.device('demo:front_door'));
    await settle(tester, 2);
    expect(find.text(en.restrictedHidden), findsOneWidget);
    await goTo(tester, AppRoutes.addDevice);
    await settle(tester, 2);
    expect(find.text(en.addDeviceTitle), findsNothing);

    await goTo(tester, AppRoutes.settingsSection('security'));
    await settle(tester, 2);
    await tapKey(tester, 'restrictedDisable');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pinField')), '1111');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 4);
    expect(find.text(en.kioskWrongPin), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pinField')), '2468');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 6);
    // Settings are open again.
    expect(find.byKey(const Key('restrictedSettings')), findsOneWidget);
    await unmount(tester);
  });
}
