import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/extras/week_wrapped.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_history.dart';

import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('counts the week from the logbook', () {
    final monday = DateTime(2026, 10, 19, 8);
    HaLogbookEntry e(String id, String state, [int day = 0]) => HaLogbookEntry(
      when: monday.add(Duration(days: day)),
      entityId: id,
      name: id,
      state: state,
    );
    final s = weekStats([
      e('light.kitchen', 'on'),
      e('light.kitchen', 'off'),
      e('light.kitchen', 'on', 2),
      e('light.hall', 'on', 2),
      e('person.ana', 'home', 2),
      e('person.ana', 'not_home', 3),
      e('person.ana', 'home', 3),
      e('person.marko', 'home', 4),
      e('lock.front', 'unlocked', 2),
      e('lock.front', 'locked', 2),
    ], const {});
    expect(s.lightsOn, 3);
    expect(s.topLight, 'light.kitchen');
    expect(s.topLightCount, 2);
    expect(s.arrivals, {'person.ana': 2, 'person.marko': 1});
    expect(s.unlocks, 1);
    expect(s.busiestDay, DateTime.wednesday);
    // Doors need their device class (unknown devices here): none counted.
    expect(s.doorOpenings, 0);
  });

  testWidgets('This week: a story, card by card, then closes', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraWrapped');
    await settle(tester, 10);
    expect(find.byKey(const Key('wrappedScreen')), findsOneWidget);
    expect(find.text(en.wrappedIntro), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      if (find.byKey(const Key('wrappedScreen')).evaluate().isEmpty) break;
      await tester.tapAt(const Offset(700, 800));
      await settle(tester, 5);
    }
    expect(find.byKey(const Key('wrappedScreen')), findsNothing);
    await unmount(tester);
  });
}
