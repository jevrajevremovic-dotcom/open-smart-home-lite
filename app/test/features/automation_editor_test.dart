import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/automations/application/routines_controller.dart';
import 'package:open_smart_home_lite/features/devices/domain/capability.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_command.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/features/devices/domain/smart_home_device.dart';

import '../helpers.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;
import 'automations_test.dart' show door;

void main() {
  testWidgets('a scene from now, an automation by hand; the door opens', (
    tester,
  ) async {
    final adapter = TestAdapter([
      door(open: false),
      testDevice(
        'hall',
        name: 'Hodnik',
        kind: DeviceKind.dimmableLight,
        capabilities: {Capability.power, Capability.brightness},
        state: const DeviceState(raw: 'on', isOn: true, brightnessPercent: 25),
      ),
    ]);
    await pumpApp(tester, size: const Size(800, 1600), adapter: adapter);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );

    // A scene: the hall light as it is now.
    await goTo(tester, AppRoutes.scenes);
    await tapKey(tester, 'newScene');
    await settle(tester, 3);
    await tapKey(tester, 'sceneDevice-test:hall');
    await tester.enterText(find.byKey(const Key('sceneName')), 'Veče');
    await tapKey(tester, 'sceneSave');
    await settle(tester, 4);
    expect(find.text(en.sceneSavedLocal), findsOneWidget);
    final scene = container.read(routinesProvider).scenes.single;
    expect(scene.name, 'Veče');
    expect((scene.actions.single.command as SetBrightness).percent, 25);
    expect(find.text('Veče'), findsWidgets, reason: 'listed with the scenes');

    // An automation: when the door opens, the hall light on.
    await tapKey(tester, 'newAutomation');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('autoName')), 'Dobrodošlica');
    await tapKey(tester, 'autoAddTrigger');
    await settle(tester, 2);
    await tapKey(tester, 'choose-device');
    await settle(tester, 2);
    await tapKey(tester, 'pick-test:door');
    await settle(tester, 2);
    await tapKey(tester, 'choose-DeviceStateTarget.open');
    await settle(tester, 2);
    expect(find.text('Ulazna vrata: ${en.autoTargetOpen}'), findsOneWidget);
    await tapKey(tester, 'autoAddAction');
    await settle(tester, 2);
    await tapKey(tester, 'pick-test:hall');
    await settle(tester, 2);
    await tapKey(tester, 'choose-on');
    await settle(tester, 2);
    await tapKey(tester, 'autoSave');
    await settle(tester, 4);
    final auto = container.read(routinesProvider).automations.single;
    expect((auto.name, auto.enabled), ('Dobrodošlica', true));

    adapter.update(door(open: true));
    await settle(tester, 4);
    expect(
      adapter.sent.map((s) => (s.$1, s.$2.runtimeType)),
      contains(('test:hall', TurnOn)),
    );
    await unmount(tester);
  });
}
