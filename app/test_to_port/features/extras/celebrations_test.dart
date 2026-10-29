import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/extras/celebrations.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_controller.dart';
import 'package:open_smart_home_lite/features/kiosk/application/kiosk_people.dart';

import '../../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, unmount;

void main() {
  test('seasons: snow to Christmas, confetti at New Year, pumpkins', () {
    expect(seasonFor(DateTime(2026, 12, 10)), Celebration.snow);
    expect(seasonFor(DateTime(2027, 1, 7)), Celebration.snow);
    expect(seasonFor(DateTime(2027, 1, 8)), isNull);
    expect(seasonFor(DateTime(2026, 12, 31)), Celebration.confetti);
    expect(seasonFor(DateTime(2027, 1, 1)), Celebration.confetti);
    expect(seasonFor(DateTime(2026, 10, 30)), Celebration.halloween);
    expect(seasonFor(DateTime(2026, 7, 1)), isNull);
  });

  test('a birthday is kept as month and day only', () {
    const p = KioskPerson(birthday: (3, 8));
    expect(p.toJson(), {'birthday': '03-08'});
    expect(KioskPerson.fromJson(p.toJson()).birthday, (3, 8));
  });

  testWidgets('a birthday on the panel: greeting and confetti; off: none', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 800));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final now = DateTime.now();
    await container.read(kioskPeopleProvider.notifier).setBirthday(
      'person.ana',
      (now.month, now.day),
    );
    container.read(kioskActiveProvider.notifier).enter();
    await goTo(tester, AppRoutes.kiosk);
    await settle(tester, 6);

    expect(find.text(en.birthdayGreeting('Ana')), findsOneWidget);
    expect(container.read(celebrationProvider), Celebration.confetti);
    expect(find.byKey(const ValueKey('celebration-confetti')), findsOneWidget);

    // Untouched for a while: it fades and stops drawing; a touch, again.
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byKey(const ValueKey('celebration-confetti')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 1);
    await tester.pump(CelebrationLayer.showFor);
    await settle(tester, 40);
    expect(opacity(), 0);
    await tester.tapAt(const Offset(640, 400));
    await settle(tester, 2);
    expect(opacity(), 1);

    await container.read(seasonalProvider.notifier).set(false);
    await settle(tester, 2);
    expect(find.byKey(const ValueKey('celebration-confetti')), findsNothing);
    await unmount(tester);
  });
}
