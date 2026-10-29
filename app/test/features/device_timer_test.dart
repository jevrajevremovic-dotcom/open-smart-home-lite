import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/timers/device_timer.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('script id is a valid, stable config id', () {
    expect(timerScriptId('light.hallway'), 'osh_timer_light_hallway');
    expect(timerScriptId('switch.${'x' * 80}').length, 64);
    expect(
      RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(timerScriptId('fan.a_b')),
      isTrue,
    );
  });

  testWidgets('turn on in 5 minutes, run by Home Assistant; cancel another', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    expect(server.stateForTest('light.hallway'), 'off');

    await goTo(tester, AppRoutes.device('light.hallway'));
    await settle(tester, 4);
    await tapKey(tester, 'deviceTimer');
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('timer-5')));
    await settle(tester, 8);

    expect(server.scripts.keys, ['osh_timer_light_hallway']);
    expect(server.stateForTest('script.osh_timer_light_hallway'), 'on');
    expect(find.byKey(const Key('deviceTimerRunning')), findsOneWidget);
    await goTo(tester, AppRoutes.scenes);
    await settle(tester, 3);
    expect(find.textContaining('tajmer'), findsNothing, reason: 'hidden');
    await goTo(tester, AppRoutes.device('light.hallway'));
    await settle(tester, 4);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await settle(tester, 6);
    expect(server.stateForTest('light.hallway'), 'on', reason: 'HA did it');
    expect(find.byKey(const Key('deviceTimerRunning')), findsNothing);

    // Off in 15 minutes, then cancelled: nothing happens.
    await tapKey(tester, 'deviceTimer');
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('timer-15')));
    await settle(tester, 8);
    await tapKey(tester, 'deviceTimerCancel');
    await settle(tester, 6);
    await tester.pump(const Duration(minutes: 16));
    await settle(tester, 4);
    expect(server.stateForTest('light.hallway'), 'on');
    await unmount(tester);
  });
}
