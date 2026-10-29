import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeClapPlatform;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

List<double> quiet(int ms) => List.filled(ms ~/ 20, 0.02);
List<double> clap() => [0.7, 0.35, 0.05, 0.03];
List<double> doubleClap() => [
  ...quiet(1000),
  ...clap(),
  ...quiet(400),
  ...clap(),
  ...quiet(800),
];

void main() {
  testWidgets('opt in, pick a light, clap twice in the kiosk', (tester) async {
    final mic = FakeClapPlatform();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      clap: mic,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    expect(server.stateForTest('light.hallway'), 'off');

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'clapSwitch');
    await settle(tester, 3);
    expect(find.text(en.clapPrivacyTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('clapAllow')));
    await settle(tester, 3);
    await tapKey(tester, 'clapTarget');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('clapSearch')), 'Hodnik');
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('clapPick-light.hallway')));
    await settle(tester, 3);
    expect(mic.listeners, 0, reason: 'only listens inside the kiosk');

    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    expect(mic.listeners, 1);

    mic.emit(doubleClap());
    await settle(tester, 8);
    expect(server.stateForTest('light.hallway'), 'on');

    mic.emit(quiet(2000));
    mic.emit(doubleClap());
    await settle(tester, 8);
    expect(server.stateForTest('light.hallway'), 'off');

    // Speech-like noise does nothing.
    mic.emit([for (var i = 0; i < 60; i++) i.isEven ? 0.6 : 0.5]);
    mic.emit(quiet(1500));
    await settle(tester, 6);
    expect(server.stateForTest('light.hallway'), 'off');
    await unmount(tester);
    expect(mic.listeners, 0, reason: 'microphone released');
  });

  testWidgets('refused microphone permission leaves it off', (tester) async {
    final mic = FakeClapPlatform(permission: false);
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      clap: mic,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'clapSwitch');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('clapAllow')));
    await settle(tester, 3);
    expect(find.text(en.clapPermissionDenied), findsOneWidget);
    expect(find.byKey(const Key('clapTarget')), findsNothing);
    await unmount(tester);
  });

  testWidgets('any device can be chosen; unlocking still asks first', (
    tester,
  ) async {
    final mic = FakeClapPlatform();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1600),
      clap: mic,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    expect(server.stateForTest('lock.front_door'), 'locked');

    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'clapSwitch');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('clapAllow')));
    await settle(tester, 3);
    await tapKey(tester, 'clapTarget');
    await settle(tester, 3);
    await tester.enterText(find.byKey(const Key('clapSearch')), 'Brava');
    await settle(tester, 2);
    expect(find.text(en.clapLockAction), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clapPick-lock.front_door')));
    await settle(tester, 3);

    await tapKey(tester, 'startKiosk');
    await settle(tester, 8);
    mic.emit(doubleClap());
    await settle(tester, 8);
    expect(
      server.stateForTest('lock.front_door'),
      'locked',
      reason: 'not without confirmation',
    );
    expect(find.byKey(const Key('confirmCriticalAction')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmCriticalAction')));
    await settle(tester, 8);
    expect(server.stateForTest('lock.front_door'), 'unlocked');
    await unmount(tester);
  });
}
