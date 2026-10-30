import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_people.dart';

import '../home_fixture.dart';
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)));

void main() {
  testWidgets('tapping a picture greets that person; again, everyone', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1280, 800));
    await settle(tester, 10);
    final container = _container(tester);
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 6);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('kioskPerson-fx:person.ana')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('kioskColumnsLeft')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapKey(tester, 'kioskPerson-fx:person.ana');
    await settle(tester, 3);
    expect(container.read(kioskUserProvider), 'fx:person.ana');
    expect(find.textContaining(', Ana'), findsWidgets);
    expect(find.text(en.kioskQuickControlsFor('Ana')), findsOneWidget);

    // Dimming forgets who was there.
    container.read(kioskDimmedProvider.notifier).set(true);
    await settle(tester);
    expect(container.read(kioskUserProvider), isNull);
    container.read(kioskDimmedProvider.notifier).set(false);
    await settle(tester);

    await tapKey(tester, 'kioskPerson-fx:person.ana');
    await settle(tester, 2);
    await tapKey(tester, 'kioskPerson-fx:person.ana');
    await settle(tester, 2);
    expect(container.read(kioskUserProvider), isNull);
    expect(find.text(en.kioskQuickControls), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('own quick controls replace the shared ones for that person', (
    tester,
  ) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(1280, 800));
    await settle(tester, 10);
    final container = _container(tester);
    await container
        .read(kioskSettingsProvider.notifier)
        .update((s) => s.copyWith(quickControls: ['shared']));
    await container.read(kioskPeopleProvider.notifier).setQuickControls(
      'fx:person.marko',
      ['mine'],
    );
    expect(container.read(kioskQuickControlsProvider), ['shared']);
    container.read(kioskUserProvider.notifier).select('fx:person.marko');
    expect(container.read(kioskQuickControlsProvider), ['mine']);
    container.read(kioskUserProvider.notifier).select('fx:person.ana');
    expect(container.read(kioskQuickControlsProvider), ['shared']);
    await unmount(tester);
  });

  testWidgets(
    'a member with their own PIN may unlock; one without (a child) may not',
    (tester) async {
      await pumpApp(
        tester,
        adapter: HomeFixture(),
        size: const Size(1280, 800),
      );
      await settle(tester, 10);
      final container = _container(tester);
      final server = HomeFixture.running;
      // No panel PIN at all: a member's PIN alone turns the check on.
      await container
          .read(kioskPeopleProvider.notifier)
          .setPin('fx:person.marko', '1357');
      expect(container.read(kioskCriticalPinRequiredProvider), isTrue);
      container.read(kioskActiveProvider.notifier).enter();
      await goTo(tester, AppRoutes.device('fx:lock.front_door', kiosk: true));
      await settle(tester, 6);

      Future<void> tryUnlock(String pin) async {
        await tapKey(tester, 'unlockButton');
        await settle(tester, 2);
        await tapKey(tester, 'confirmCriticalAction');
        await settle(tester, 2);
        await tester.enterText(find.byKey(const Key('pinField')), pin);
        await tapKey(tester, 'pinSubmit');
        await settle(tester, 6);
      }

      // Anything but Marko's PIN is refused (there is no panel PIN to try).
      await tryUnlock('0000');
      expect(find.text(en.kioskWrongPin), findsOneWidget);
      expect(server.stateOf('fx:lock.front_door'), 'locked');
      await tester.tap(find.text(en.cancel));
      await settle(tester, 2);

      await tryUnlock('1357');
      expect(server.stateOf('fx:lock.front_door'), 'unlocked');
      // The PIN also told the panel who is there…
      expect(container.read(kioskUserProvider), 'fx:person.marko');
      // Kiosk mode itself is still on: a member's PIN does not exit it.
      expect(container.read(kioskActiveProvider), isTrue);
      await unmount(tester);
    },
  );

  testWidgets('a member PIN is set in Settings', (tester) async {
    await pumpApp(tester, adapter: HomeFixture(), size: const Size(800, 1600));
    await settle(tester, 10);
    final container = _container(tester);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await settle(tester, 4);
    await tapKey(tester, 'kioskPersonSetPin-fx:person.ana');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pinField')), '2580');
    await tapKey(tester, 'pinSubmit');
    await settle(tester, 6); // first dialog closes, confirmation opens
    await tester.enterText(find.byKey(const Key('pinField')), '2580');
    await tapKey(tester, 'pinSubmit');
    await settle(tester, 3);
    expect(
      container.read(kioskPeopleProvider)['fx:person.ana']?.hasPin,
      isTrue,
    );
    expect(find.text(en.kioskPersonPinSet), findsOneWidget);
    await unmount(tester);
  });
}
