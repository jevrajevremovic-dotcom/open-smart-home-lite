import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/automations/domain/simple_automation.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  test('config in the current HA format', () {
    final config = const SimpleAutomation(
      alias: 'Morning',
      triggers: [TimeTrigger(7, 5)],
      conditions: [
        WeekdayCondition({5, 1}),
      ],
      actions: [AutomationAction('light.hall', 'turn_on')],
    ).toConfig('123');
    expect(config['triggers'], [
      {'trigger': 'time', 'at': '07:05:00'},
    ]);
    expect(config['conditions'], [
      {
        'condition': 'time',
        'weekday': ['mon', 'fri'],
      },
    ]);
    expect(config['actions'], [
      {
        'action': 'light.turn_on',
        'target': {'entity_id': 'light.hall'},
      },
    ]);
    final sun = const SimpleAutomation(
      alias: 'x',
      triggers: [SunTrigger(sunset: true, offsetMinutes: -30)],
      actions: [],
    ).toConfig('1');
    expect((sun['triggers']! as List).single, {
      'trigger': 'sun',
      'event': 'sunset',
      'offset': '-00:30:00',
    });
    expect(sun['conditions'], isEmpty);
  });

  testWidgets('create "door opens → hallway light on", then delete it', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.scenes);
    await tapKey(tester, 'newAutomation');
    await settle(tester, 4);

    await tapKey(tester, 'autoSave');
    await settle(tester, 2);
    expect(find.text(en.autoIncomplete), findsOneWidget);

    await tester.enterText(find.byKey(const Key('autoName')), 'Ulaz noću');
    await tapKey(tester, 'autoAddTrigger');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('trigKind-device')));
    await settle(tester, 1);
    await tapKey(tester, 'autoTriggerDevice');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pickSearch')), 'Ulazna');
    await settle(tester, 1);
    await tester.tap(
      find.byKey(const ValueKey('pick-binary_sensor.front_door')),
    );
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('autoState-on')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('trigOk')));
    await settle(tester, 3);

    await tapKey(tester, 'autoAddAction');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pickSearch')), 'Hodnik');
    await settle(tester, 1);
    await tester.tap(find.byKey(const ValueKey('pick-light.hallway')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('svc-turn_on')));
    await settle(tester, 2);

    await tapKey(tester, 'autoSave');
    await settle(tester, 8);
    expect(find.text(en.autoSaved), findsOneWidget);
    final config = server.automations.values.single;
    expect(config['alias'], 'Ulaz noću');
    expect((config['triggers']! as List).single, {
      'trigger': 'state',
      'entity_id': 'binary_sensor.front_door',
      'to': 'on',
    });
    expect(find.text('Ulaz noću'), findsOneWidget, reason: 'listed');

    await tester.tap(find.text('Ulaz noću'));
    await settle(tester, 4);
    await tapKey(tester, 'deleteAutomation');
    await settle(tester, 2);
    await tapKey(tester, 'confirmDeleteAutomation');
    await settle(tester, 8);
    expect(server.automations, isEmpty);
    expect(find.text('Ulaz noću'), findsNothing);
    await unmount(tester);
  });

  test('simple configs read back; complex ones are left to HA', () {
    for (final a in const [
      SimpleAutomation(
        alias: 'A',
        triggers: [TimeTrigger(6, 30)],
        conditions: [
          WeekdayCondition({1, 2}),
        ],
        actions: [AutomationAction('light.a', 'turn_on')],
      ),
      SimpleAutomation(
        alias: 'B',
        triggers: [
          DeviceTrigger('binary_sensor.d', 'on'),
          NumericTrigger('sensor.t', above: true, threshold: 25.5),
        ],
        conditions: [
          TimeWindowCondition(
            after: ClockTime(22, 0),
            before: ClockTime(6, 30),
          ),
          StateCondition('person.ana', 'home'),
          SunCondition(dark: true),
        ],
        actions: [AutomationAction('cover.c', 'close_cover')],
      ),
      SimpleAutomation(
        alias: 'C',
        triggers: [SunTrigger(sunset: false, offsetMinutes: -45)],
        actions: [AutomationAction('scene.s', 'turn_on')],
      ),
    ]) {
      final back = SimpleAutomation.tryParse(a.toConfig('1'))!;
      expect(back.toConfig('1'), a.toConfig('1'), reason: a.alias);
    }
    // Legacy format (platform/service) is understood too.
    expect(
      SimpleAutomation.tryParse({
        'alias': 'Old',
        'trigger': [
          {'platform': 'time', 'at': '08:00:00'},
        ],
        'action': [
          {'service': 'light.turn_off', 'entity_id': 'light.x'},
        ],
      }),
      isNotNull,
    );
    expect(
      SimpleAutomation.tryParse({
        'triggers': [
          {'trigger': 'time', 'at': '08:00:00'},
          {'trigger': 'template', 'value_template': '{{ true }}'},
        ],
        'actions': [
          {
            'action': 'light.turn_on',
            'target': {'entity_id': 'light.x'},
          },
        ],
      }),
      isNull,
      reason: 'template trigger',
    );
  });

  testWidgets('edit an automation made in the app', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);
    server.saveAutomation(
      '42',
      const SimpleAutomation(
        alias: 'Jutro',
        triggers: [TimeTrigger(7, 0)],
        actions: [AutomationAction('light.hallway', 'turn_on')],
      ).toConfig('42'),
    );
    await settle(tester, 4);
    await goTo(tester, AppRoutes.device('automation.jutro'));
    await settle(tester, 4);
    await tapKey(tester, 'editAutomation');
    await settle(tester, 6);
    expect(find.text(en.autoEdit), findsWidgets);
    expect(find.byKey(const Key('autoSave')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('autoName')), 'Rano jutro');
    await tester.tap(find.byKey(const ValueKey('autoDay-1')));
    await settle(tester, 1);
    await tapKey(tester, 'autoSave');
    await settle(tester, 8);
    final config = server.automations['42']!;
    expect(config['alias'], 'Rano jutro');
    expect(config['conditions'], [
      {
        'condition': 'time',
        'weekday': ['mon'],
      },
    ]);
    await unmount(tester);
  });

  test('one HA time condition with weekdays and a window is split', () {
    final a = SimpleAutomation.tryParse({
      'triggers': [
        {'trigger': 'time', 'at': '08:00:00'},
      ],
      'conditions': [
        {
          'condition': 'time',
          'after': '07:00:00',
          'before': '09:00:00',
          'weekday': 'sat',
        },
      ],
      'actions': [
        {'action': 'light.turn_on', 'entity_id': 'light.x'},
      ],
    })!;
    expect(a.conditions, hasLength(2));
    expect((a.conditions.first as WeekdayCondition).weekdays, {6});
    expect(
      (a.conditions.last as TimeWindowCondition).after,
      const ClockTime(7, 0),
    );
    // Things the editor would silently drop are left to HA.
    expect(
      SimpleAutomation.tryParse({
        'triggers': [
          {'trigger': 'state', 'entity_id': 'light.x', 'to': 'on', 'for': 5},
        ],
        'actions': [
          {'action': 'light.turn_on', 'entity_id': 'light.x'},
        ],
      }),
      isNull,
    );
    expect(
      SimpleAutomation.tryParse({
        'triggers': [
          {'trigger': 'time', 'at': '08:00:00'},
        ],
        'actions': [
          {
            'action': 'light.turn_on',
            'target': {'entity_id': 'light.x'},
            'data': {'brightness': 10},
          },
        ],
      }),
      isNull,
    );
  });

  testWidgets('two triggers, a value threshold and "only when dark"', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final server = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    ).read(mockHomeAssistantServerProvider);

    await goTo(tester, AppRoutes.scenes);
    await tapKey(tester, 'newAutomation');
    await settle(tester, 4);
    await tester.enterText(find.byKey(const Key('autoName')), 'Toplo');

    // Trigger 1: a time (default 07:00).
    await tapKey(tester, 'autoAddTrigger');
    await settle(tester, 3);
    await tester.tap(find.byKey(const Key('trigOk')));
    await settle(tester, 3);

    // Trigger 2: temperature rises above 25.
    await tapKey(tester, 'autoAddTrigger');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('trigKind-value')));
    await settle(tester, 1);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('trigOk'))).onPressed,
      isNull,
      reason: 'no sensor yet',
    );
    await tester.tap(find.byKey(const Key('autoTriggerSensor')));
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pickSearch')), 'dnevna');
    await settle(tester, 1);
    await tester.tap(
      find.byKey(const ValueKey('pick-sensor.living_room_temperature')),
    );
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('autoThreshold')), '25,5');
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('trigOk')));
    await settle(tester, 3);
    expect(find.text(en.autoAnyTrigger), findsOneWidget);

    await tapKey(tester, 'autoAddCondition');
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('cond-dark')));
    await settle(tester, 3);
    expect(find.text(en.autoCondDark), findsOneWidget);

    await tapKey(tester, 'autoAddAction');
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('pickSearch')), 'Hodnik');
    await settle(tester, 1);
    await tester.tap(find.byKey(const ValueKey('pick-light.hallway')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('svc-turn_on')));
    await settle(tester, 2);

    await tapKey(tester, 'autoSave');
    await settle(tester, 8);
    final config = server.automations.values.single;
    expect(config['triggers'], [
      {'trigger': 'time', 'at': '07:00:00'},
      {
        'trigger': 'numeric_state',
        'entity_id': 'sensor.living_room_temperature',
        'above': 25.5,
      },
    ]);
    expect(config['conditions'], [
      {'condition': 'state', 'entity_id': 'sun.sun', 'state': 'below_horizon'},
    ]);
    expect(SimpleAutomation.tryParse(config), isNotNull, reason: 'editable');
    await unmount(tester);
  });
}
