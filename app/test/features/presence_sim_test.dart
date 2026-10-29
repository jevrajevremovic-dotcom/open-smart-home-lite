import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/automations/domain/simple_automation.dart';
import 'package:open_smart_home_lite/features/presence_sim/presence_simulation.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('automation: away condition, random light, all off at the end', () {
    const sim = PresenceSimulation(
      lights: ['light.a', 'light.b'],
      end: ClockTime(23, 30),
    );
    final c = sim.toAutomation(alias: 'Presence', description: 'd');
    expect(c['conditions'], [
      {'condition': 'numeric_state', 'entity_id': 'zone.home', 'below': 1},
    ]);
    expect(c['triggers'], [
      {'trigger': 'time_pattern', 'minutes': '/15', 'id': 'tick'},
      {'trigger': 'time', 'at': '23:30:00', 'id': 'end'},
    ]);
    final step = (c['actions']! as List).single as Map;
    expect(step['then'], [
      {
        'action': 'light.turn_off',
        'target': {
          'entity_id': ['light.a', 'light.b'],
        },
      },
    ]);
    final orElse = step['else']! as List;
    expect(orElse.first, {
      'condition': 'state',
      'entity_id': 'sun.sun',
      'state': 'below_horizon',
    });
    expect(orElse[1], {
      'condition': 'time',
      'after': '12:00:00',
      'before': '23:30:00',
    });
    expect((orElse.last as Map)['else'], [
      {
        'action': 'light.turn_on',
        'target': {'entity_id': '{{ osh_light }}'},
      },
    ]);

    final alarm = sim
        .copyWith(
          when: PresenceWhen.alarm,
          alarmId: 'alarm_control_panel.home',
          fromSunset: false,
          start: const ClockTime(19, 0),
        )
        .toAutomation(alias: 'P', description: 'd');
    expect(alarm['conditions'], [
      {
        'condition': 'state',
        'entity_id': 'alarm_control_panel.home',
        'state': 'armed_away',
      },
    ]);
    final back = PresenceSimulation.fromAutomation(alarm)!;
    expect(back.lights, ['light.a', 'light.b']);
    expect(back.when, PresenceWhen.alarm);
    expect(back.alarmId, 'alarm_control_panel.home');
    expect(back.fromSunset, isFalse);
    expect(back.start, const ClockTime(19, 0));
    expect(
      PresenceSimulation.fromAutomation(
        sim
            .copyWith(when: PresenceWhen.always)
            .toAutomation(alias: 'P', description: 'd'),
      )!.when,
      PresenceWhen.always,
    );
    expect(PresenceSimulation.fromAutomation({'alias': 'x'}), isNull);
  });

  testWidgets('set up, switch off and remove in Home Assistant', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.settingsSection('security'));
    await tapKey(tester, 'openPresenceSim');
    await settle(tester, 4);
    expect(find.text(en.presenceNotSaved), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('presenceSave')))
          .onPressed,
      isNull,
      reason: 'no lights chosen yet',
    );
    await tester.tap(find.byKey(const ValueKey('presenceLight-light.hallway')));
    await tester.tap(
      find.byKey(const ValueKey('presenceLight-light.living_room_main')),
    );
    await settle(tester, 2);
    await tester.ensureVisible(find.byKey(const Key('presenceSave')));
    await tapKey(tester, 'presenceSave');
    await settle(tester, 4);
    expect(find.text(en.presenceSaved), findsOneWidget);
    final saved = server.automations[presenceSimId]!;
    expect(saved['alias'], en.presenceTitle);
    expect(PresenceSimulation.fromAutomation(saved)!.lights, [
      'light.hallway',
      'light.living_room_main',
    ]);

    // Its automation entity: on, can be switched off.
    await tester.scrollUntilVisible(
      find.byKey(const Key('presenceOn')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 2);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('presenceOn'))).value,
      isTrue,
    );
    await tapKey(tester, 'presenceOn');
    await settle(tester, 4);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('presenceOn'))).value,
      isFalse,
    );

    // Opened again: the saved settings come back.
    await goTo(tester, AppRoutes.presenceSim);
    await settle(tester, 4);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(const ValueKey('presenceLight-light.hallway')),
          )
          .selected,
      isTrue,
    );

    await tester.ensureVisible(find.byKey(const Key('presenceRemove')));
    await tapKey(tester, 'presenceRemove');
    await settle(tester, 4);
    expect(server.automations, isNot(contains(presenceSimId)));
    expect(find.text(en.presenceNotSaved), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without an administrator account it says so', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    ProviderScope.containerOf(tester.element(find.byType(SmartHomeApp)))
            .read(mockHomeAssistantServerProvider)
            .configAdmin =
        false;
    await goTo(tester, AppRoutes.presenceSim);
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('presenceLight-light.hallway')));
    await tester.ensureVisible(find.byKey(const Key('presenceSave')));
    await tapKey(tester, 'presenceSave');
    await settle(tester, 4);
    expect(find.text(en.presenceNeedsAdmin), findsOneWidget);
    await unmount(tester);
  });
}
