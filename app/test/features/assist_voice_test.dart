import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';

import '../helpers.dart' show FakeAssistLaunch, FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  testWidgets('a spoken question gets a spoken answer; can be turned off', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      speech: speech,
    );
    await settle(tester, 10);
    await tapKey(tester, 'openAssist');
    await settle(tester, 6);
    await tapKey(tester, 'assistMic');
    await settle(tester, 2);
    await tapKey(tester, 'voiceOnDeviceOnly');
    await settle(tester, 10);
    expect(speech.said, ['Turned off the lights.']);

    // Typed questions are not read aloud.
    await tester.enterText(find.byKey(const Key('assistInput')), 'lights on');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester, 10);
    expect(speech.said, hasLength(1));
    await unmount(tester);
  });

  testWidgets('spoken answers off in settings', (tester) async {
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      speech: speech,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('assist'));
    await tapKey(tester, 'assistSpeak');
    await settle(tester, 2);
    await goTo(tester, AppRoutes.home);
    await settle(tester, 4);
    await tapKey(tester, 'openAssist');
    await settle(tester, 6);
    await tapKey(tester, 'assistMic');
    await settle(tester, 2);
    await tapKey(tester, 'voiceOnDeviceOnly');
    await settle(tester, 10);
    expect(find.text('Turned off the lights.'), findsOneWidget);
    expect(speech.said, isEmpty);
    await unmount(tester);
  });

  testWidgets('opened as the phone assistant: Assist listens at once', (
    tester,
  ) async {
    final launch = FakeAssistLaunch(initial: true);
    final speech = FakeSpeechOutput();
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(800, 1400),
      speech: speech,
      assistLaunch: launch,
    );
    await settle(tester, 10);
    expect(find.byKey(const Key('assistSheet')), findsOneWidget);
    // Listening started without a tap (privacy question first, once).
    expect(find.text(en.voicePrivacyBody), findsOneWidget);
    await tapKey(tester, 'voiceOnDeviceOnly');
    await settle(tester, 10);
    expect(speech.said, ['Turned off the lights.']);
    Navigator.of(tester.element(find.byKey(const Key('assistSheet')))).pop();
    await settle(tester, 6);

    await goTo(tester, AppRoutes.settingsSection('assist'));
    await settle(tester, 2);
    await tapKey(tester, 'assistDefault');
    expect(launch.settingsOpened, 1);
    await unmount(tester);
  });
}
