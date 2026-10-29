import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart' show FakeAlertNotifier, FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show goTo, pumpApp, settle, tapKey, unmount;

Future<MockHomeAssistantServer> _registered(
  WidgetTester tester, {
  required FakeSpeechOutput speech,
  required FakeAlertNotifier alerts,
}) async {
  await pumpApp(
    tester,
    signedIn: true,
    size: const Size(1280, 800),
    speech: speech,
    alerts: alerts,
  );
  await settle(tester, 10);
  final server = ProviderScope.containerOf(
    tester.element(find.byType(SmartHomeApp)),
  ).read(mockHomeAssistantServerProvider);
  await goTo(tester, AppRoutes.settingsSection('notifications'));
  await tapKey(tester, 'haPushTile');
  await settle(tester, 3);
  await tester.enterText(find.byKey(const Key('haPushName')), 'Zidni tablet');
  await tester.tap(find.byKey(const Key('haPushRegister')));
  await settle(tester, 8);
  return server;
}

const _tts = {
  'message': 'TTS',
  'data': {'tts_text': 'Večera je gotova'},
};

void main() {
  testWidgets('kiosk: "TTS" from Home Assistant is spoken and shown', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    final alerts = FakeAlertNotifier();
    final server = await _registered(tester, speech: speech, alerts: alerts);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);

    server.callService('notify', 'mobile_app_zidni_tablet', _tts);
    await settle(tester, 4);
    expect(speech.said, ['Večera je gotova']);
    expect(find.byKey(const Key('kioskAnnouncement')), findsOneWidget);
    expect(find.text('Večera je gotova'), findsOneWidget);
    expect(alerts.messages, isEmpty, reason: 'spoken, not a notification');
    await tester.pump(const Duration(seconds: 16));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskAnnouncement')), findsNothing);
    await unmount(tester);
  });

  testWidgets('without text-to-speech it arrives as a message', (tester) async {
    final speech = FakeSpeechOutput(supported: false);
    final alerts = FakeAlertNotifier();
    final server = await _registered(tester, speech: speech, alerts: alerts);
    server.callService('notify', 'mobile_app_zidni_tablet', _tts);
    await settle(tester, 4);
    expect(alerts.messages.single, (null, 'Večera je gotova'));
    await unmount(tester);
  });
}
