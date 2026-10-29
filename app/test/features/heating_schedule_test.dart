import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/heating_schedule/heating_schedule.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

/// The snack bar would cover the button at the bottom.
void hideSnack(WidgetTester tester) => tester
    .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
    .hideCurrentSnackBar();

void main() {
  test('automation: a time trigger per time, weekdays chosen per point', () {
    final s = HeatingSchedule.suggested('climate.living_room');
    final c = s.automation(AppLocalizationsEn(), 'Klima');
    expect(s.id, 'osh_schedule_climate_living_room');
    expect(
      [for (final t in c['triggers']! as List) (t as Map)['at']],
      ['06:00:00', '08:00:00', '16:00:00', '22:00:00', '23:00:00'],
    );
    final options =
        ((c['actions']! as List).single as Map)['choose']! as List<Object?>;
    expect(options, hasLength(6));
    // 08:00 on workdays → 18°, on the weekend → 21°.
    final eight = [
      for (final o in options)
        if (((o! as Map)['conditions'] as List).first case {'id': '08:00'})
          o as Map,
    ];
    expect(eight.map((o) => (o['conditions'] as List).last), [
      {'condition': 'time', 'weekday': HeatingSchedule.workdayNames},
      {'condition': 'time', 'weekday': HeatingSchedule.weekendNames},
    ]);
    expect(eight.map((o) => ((o['sequence'] as List).single as Map)['data']), [
      {'temperature': 18.0},
      {'temperature': 21.0},
    ]);
    expect(HeatingSchedule.fromAutomation(c)!.workdays, s.workdays);
    expect(HeatingSchedule.fromAutomation(c)!.weekend, s.weekend);
  });

  test('what holds now and what comes next', () {
    final s = HeatingSchedule.suggested('climate.x');
    // Monday 07:00: 21° since 06:00, then 18° at 08:00.
    var (now, next) = s.around(DateTime(2026, 10, 19, 7));
    expect((now!.hhmm, next!.hhmm), ('06:00', '08:00'));
    // Saturday 02:00: Friday's 22:00 still holds; 08:00 is next.
    (now, next) = s.around(DateTime(2026, 10, 24, 2));
    expect((now!.hhmm, now.temperature, next!.hhmm), ('22:00', 18.0, '08:00'));
    // Sunday 23:30: Monday 06:00 is next.
    (now, next) = s.around(DateTime(2026, 10, 25, 23, 30));
    expect((now!.hhmm, next!.hhmm), ('23:00', '06:00'));
  });

  testWidgets('thermostat: suggested week, warmer, saved, changed, removed', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.device('climate.living_room'));
    await settle(tester, 6);
    await tester.ensureVisible(find.byKey(const Key('heatingSchedule')));
    await tapKey(tester, 'heatingSchedule');
    await settle(tester, 3);
    expect(find.text(en.heatingScheduleWorkdays), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    // 06:00 on workdays: half a degree warmer.
    await tapKey(tester, 'scheduleWarmer-w-0');
    await settle(tester, 1);
    expect(find.text('21.5°'), findsOneWidget);
    // One weekend time less.
    await tapKey(tester, 'scheduleDelete-e-1');
    await settle(tester, 1);
    await tapKey(tester, 'heatingScheduleSave');
    await settle(tester, 6);
    expect(find.text(en.heatingScheduleSaved), findsOneWidget);
    final saved = HeatingSchedule.fromAutomation(
      server.automations['osh_schedule_climate_living_room']!,
    )!;
    expect(saved.workdays.first, const SchedulePoint(360, 21.5));
    expect(saved.weekend, [const SchedulePoint(480, 21)]);
    expect(find.byKey(const Key('heatingScheduleSet')), findsOneWidget);

    // Read back for changing; a new weekend time.
    await tester.ensureVisible(find.byKey(const Key('heatingScheduleEdit')));
    hideSnack(tester);
    await settle(tester, 1);
    await tapKey(tester, 'heatingScheduleEdit');
    await settle(tester, 4);
    expect(find.text('21.5°'), findsOneWidget);
    await tapKey(tester, 'scheduleAdd-e');
    await settle(tester, 1);
    await tapKey(tester, 'heatingScheduleSave');
    await settle(tester, 6);
    expect(
      HeatingSchedule.fromAutomation(
        server.automations['osh_schedule_climate_living_room']!,
      )!.weekend.map((p) => p.hhmm),
      ['08:00', '10:00'],
    );

    hideSnack(tester);
    await settle(tester, 1);
    await tapKey(tester, 'heatingScheduleEdit');
    await settle(tester, 4);
    await tester.ensureVisible(find.byKey(const Key('heatingScheduleRemove')));
    await tapKey(tester, 'heatingScheduleRemove');
    await settle(tester, 6);
    expect(server.automations, isEmpty);
    expect(find.byKey(const Key('heatingSchedule')), findsOneWidget);
    await unmount(tester);
  });
}
