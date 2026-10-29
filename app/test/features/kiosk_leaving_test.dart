import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../helpers.dart' show FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('kiosk "I\'m leaving": lists, switches off, arms, says bye', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      speech: speech,
    );
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    expect(server.stateForTest('light.living_room_main'), 'on');

    await tapKey(tester, 'kioskLeaving');
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskLeavingDialog')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('leaving-light.living_room_main')),
      findsOneWidget,
    );
    await tapKey(tester, 'kioskLeavingGo');
    await settle(tester, 10);
    expect(server.stateForTest('light.living_room_main'), 'off');
    expect(server.stateForTest('light.living_room_ambient'), 'off');
    expect(server.stateForTest('alarm_control_panel.home_alarm'), 'armed_away');
    expect(speech.said, [en.kioskLeavingBye]);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 3);
    expect(find.byKey(const Key('kioskLeavingDialog')), findsNothing);
    await unmount(tester);
  });
}
