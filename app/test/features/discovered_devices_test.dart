import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/add_device/data/discovery_flows.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_config_flow.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  group('config flow parsing', () {
    test('discovered flows keep name, handler and source', () {
      final list = HaDiscoveredFlow.parseList([
        {
          'flow_id': 'a1',
          'handler': 'hue',
          'context': {
            'source': 'zeroconf',
            'title_placeholders': {'name': 'Hue Bridge'},
          },
        },
        {
          'flow_id': 'b2',
          'handler': 'x',
          'context': {'source': 'user'},
        },
        {'handler': 'broken'},
      ]);
      expect(list.map((f) => (f.flowId, f.name, f.source)), [
        ('a1', 'Hue Bridge', 'zeroconf'),
        ('b2', null, 'user'),
      ]);
      expect(DiscoveryFlows.discoverySources.contains('user'), isFalse);
    });

    test('form fields: classic types and selectors', () {
      final step = HaFlowStep.parse({
        'type': 'form',
        'flow_id': 'f',
        'handler': 'h',
        'step_id': 'user',
        'data_schema': [
          {'name': 'host', 'type': 'string', 'required': true},
          {'name': 'port', 'type': 'integer', 'default': 80},
          {'name': 'password', 'type': 'string'},
          {
            'name': 'mode',
            'type': 'select',
            'options': [
              ['a', 'Mode A'],
              ['b', 'Mode B'],
            ],
          },
          {
            'name': 'ssl',
            'selector': {'boolean': {}},
          },
          {
            'name': 'area',
            'selector': {'area': {}},
          },
        ],
        'errors': {'base': 'cannot_connect'},
      });
      final form = step as HaFlowForm;
      expect(form.fields.map((f) => f.kind), [
        HaFieldKind.text,
        HaFieldKind.number,
        HaFieldKind.text,
        HaFieldKind.select,
        HaFieldKind.boolean,
        HaFieldKind.unsupported,
      ]);
      expect(form.fields[2].secret, isTrue);
      expect(form.fields[3].options.last, ('b', 'Mode B'));
      expect(form.supported, isFalse);
      expect(form.errors['base'], 'cannot_connect');
    });

    test('other step types', () {
      expect(
        HaFlowStep.parse({'type': 'create_entry', 'title': 'Lamp'}),
        isA<HaFlowDone>().having((d) => d.title, 'title', 'Lamp'),
      );
      expect(
        HaFlowStep.parse({'type': 'abort', 'reason': 'already_configured'}),
        isA<HaFlowAborted>(),
      );
      expect(
        HaFlowStep.parse({
          'type': 'menu',
          'menu_options': ['a', 'b'],
        }),
        isA<HaFlowMenu>().having((m) => m.options, 'options', ['a', 'b']),
      );
      expect(HaFlowStep.parse({'type': 'external'}), isA<HaFlowUnsupported>());
    });

    test('texts use HA translations with placeholders', () {
      const t = FlowTexts(
        {'component.x.config.step.s.description': 'Set up `{model}`?'},
        'x',
        {'model': 'Plug'},
      );
      expect(t.stepDescription('s'), 'Set up Plug?');
      expect(t.field('s', 'noise_psk'), 'Noise psk');
    });
  });

  testWidgets(
    'add discovered Wi-Fi devices: confirm, then a form with validation',
    (tester) async {
      await pumpApp(tester, signedIn: true, size: const Size(800, 1400));
      await settle(tester, 10);
      await goTo(tester, AppRoutes.addDevice);
      await tapKey(tester, 'addWifi');
      await settle(tester, 6);
      expect(
        find.byKey(const ValueKey('discovered-flowshelly01')),
        findsOneWidget,
      );
      expect(find.text('kitchen-sensor'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('discovered-flowshelly01')));
      await settle(tester, 8);
      expect(
        find.text('Do you want to set up the Shelly Plug S at 192.168.1.42?'),
        findsOneWidget,
      );
      await tapKey(tester, 'flowSubmit');
      await settle(tester, 8);
      expect(find.text(en.flowDone('Shelly Plug S')), findsOneWidget);
      expect(find.text(en.flowDoneDevices), findsOneWidget);
      await tapKey(tester, 'flowFinish');
      await settle(tester, 8);
      expect(
        find.byKey(const ValueKey('discovered-flowshelly01')),
        findsNothing,
        reason: 'added, so no longer listed',
      );

      await tester.tap(find.byKey(const ValueKey('discovered-flowesphome01')));
      await settle(tester, 8);
      await tapKey(tester, 'flowSubmit');
      await settle(tester, 8);
      expect(find.text('Enter encryption key'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('flowField-noise_psk')),
        'short',
      );
      await tapKey(tester, 'flowSubmit');
      await settle(tester, 8);
      expect(
        find.text('The transport encryption key is invalid.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('flowField-noise_psk')),
        'a-long-enough-key',
      );
      await tapKey(tester, 'flowSubmit');
      await settle(tester, 8);
      expect(find.text(en.flowDone('kitchen-sensor')), findsOneWidget);
      expect(find.text('Kuhinja temperatura'), findsOneWidget);
      await unmount(tester);
    },
  );
}
