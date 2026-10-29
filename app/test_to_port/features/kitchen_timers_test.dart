import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/timers/kitchen_timers.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';

import '../helpers.dart' show FakeClapPlatform, FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('timer commands in Serbian and English', () {
    expect(
      parseTimerCommand('postavi tajmer 10 minuta'),
      const Duration(minutes: 10),
    );
    expect(
      parseTimerCommand('Tajmer na pola sata'),
      const Duration(minutes: 30),
    );
    expect(
      parseTimerCommand('tajmer 1 sat i 15 minuta'),
      const Duration(hours: 1, minutes: 15),
    );
    expect(
      parseTimerCommand('pokreni tajmer 90 sekundi'),
      const Duration(seconds: 90),
    );
    expect(
      parseTimerCommand('set a timer for 5 minutes'),
      const Duration(minutes: 5),
    );
    expect(parseTimerCommand('timer for an hour'), const Duration(hours: 1));
    expect(parseTimerCommand('tajmer 7'), const Duration(minutes: 7));
    expect(parseTimerCommand('ugasi svetla'), isNull);
    expect(parseTimerCommand('turn on the light for 5 minutes'), isNull);
    expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(
      formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  Future<ProviderContainer> kiosk(
    WidgetTester tester, {
    FakeSpeechOutput? speech,
    FakeClapPlatform? mic,
    MockHomeAssistantServer? server,
  }) async {
    await pumpApp(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
      speech: speech,
      clap: mic,
      server: server,
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 6);
    return ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)));
  }

  testWidgets('kiosk: start from the header, countdown pill, cancel', (
    tester,
  ) async {
    final container = await kiosk(tester);
    await tapKey(tester, 'kioskTimer');
    await settle(tester, 3);
    await tapKey(tester, 'timerMore');
    await tapKey(tester, 'timerMore');
    await settle(tester, 1);
    expect(find.text('12 min'), findsOneWidget);
    await tapKey(tester, 'timerStart');
    await settle(tester, 3);
    final timers = container.read(kitchenTimersProvider);
    expect(timers.single.duration, const Duration(minutes: 12));
    final pill = find.byKey(ValueKey('kioskTimer-${timers.single.id}'));
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: find.textContaining('11:5')),
      findsOneWidget,
    );

    await tester.tap(pill);
    await settle(tester, 3);
    await tapKey(tester, 'timerCancel');
    await settle(tester, 3);
    expect(container.read(kitchenTimersProvider), isEmpty);
    await unmount(tester);
  });

  testWidgets('kiosk: a finished timer is shown and spoken until stopped', (
    tester,
  ) async {
    final speech = FakeSpeechOutput();
    final container = await kiosk(tester, speech: speech);
    await container
        .read(kitchenTimersProvider.notifier)
        .start(
          const Duration(minutes: 3),
          now: DateTime.now().subtract(const Duration(minutes: 3)),
        );
    await tester.pump(const Duration(seconds: 2));
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskTimerDone')), findsOneWidget);
    expect(find.text(en.timerDone('3 min')), findsOneWidget);
    expect(speech.said, [en.timerDoneSpeech('3 min')]);

    await tapKey(tester, 'timerSnooze');
    await settle(tester, 2);
    expect(find.byKey(const Key('kioskTimerDone')), findsNothing);
    expect(
      container.read(kitchenTimersProvider).single.duration,
      const Duration(minutes: 4),
    );
    await container
        .read(kitchenTimersProvider.notifier)
        .cancel(container.read(kitchenTimersProvider).single.id);
    await settle(tester, 2);
    await unmount(tester);
  });

  testWidgets('voice: Assist starts a timer on the device, not in HA', (
    tester,
  ) async {
    final container = await kiosk(tester);
    await tapKey(tester, 'kioskAssist');
    await settle(tester, 4);
    await tester.enterText(
      find.byKey(const Key('assistInput')),
      'set a timer for 5 minutes',
    );
    await tapKey(tester, 'assistSend');
    await settle(tester, 3);
    expect(find.text(en.timerStarted('5 min')), findsOneWidget);
    expect(
      container.read(kitchenTimersProvider).single.duration,
      const Duration(minutes: 5),
    );
    await container
        .read(kitchenTimersProvider.notifier)
        .cancel(container.read(kitchenTimersProvider).single.id);
    await settle(tester, 2);
    await unmount(tester);
  });

  testWidgets('voice: the wake word starts a timer too', (tester) async {
    final mic = FakeClapPlatform();
    final speech = FakeSpeechOutput();
    final server = MockHomeAssistantServer()
      ..assistHeard = 'set a timer for 10 minutes';
    final container = await kiosk(
      tester,
      speech: speech,
      mic: mic,
      server: server,
    );
    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(wakeWordEnabled: true));
    await settle(tester, 4);
    mic.emitAudio(1, loud: true);
    mic.emitAudio(5);
    await settle(tester, 6);
    expect(speech.said, [en.timerStarted('10 min')]);
    expect(
      container.read(kitchenTimersProvider).single.duration,
      const Duration(minutes: 10),
    );
    await container
        .read(kitchenTimersProvider.notifier)
        .cancel(container.read(kitchenTimersProvider).single.id);
    await settle(tester, 2);
    await unmount(tester);
  });
}
