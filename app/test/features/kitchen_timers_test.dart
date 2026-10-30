import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/timers/kitchen_timers.dart';

import '../home_fixture.dart';
import '../helpers.dart' show FakeClapPlatform, FakeSpeechOutput;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  Future<ProviderContainer> kiosk(
    WidgetTester tester, {
    FakeSpeechOutput? speech,
    FakeClapPlatform? mic,
  }) async {
    await pumpApp(
      tester,
      adapter: HomeFixture(),
      size: const Size(1280, 800),
      speech: speech,
      clap: mic,
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
}
