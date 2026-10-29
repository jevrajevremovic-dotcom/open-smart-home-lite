import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/features/extras/batteries.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart'
    show en, pumpApp, settle, tapKey, unmount;

void main() {
  test('reminder: any battery sensor below the line, then the messages', () {
    final c = batteryReminderAutomation(
      AppLocalizationsEn(),
      sensorIds: ['sensor.a_battery', 'sensor.b_battery'],
      notify: ['notify.mobile_app_marko'],
    );
    expect(c['triggers'], [
      {
        'trigger': 'numeric_state',
        'entity_id': ['sensor.a_battery', 'sensor.b_battery'],
        'below': batteryLowPercent + 1,
      },
    ]);
    final actions = c['actions']! as List;
    expect((actions.first as Map)['action'], 'notify.mobile_app_marko');
    expect((actions.last as Map)['action'], 'persistent_notification.create');
    expect(
      '${(actions.last as Map)['data']}',
      contains('{{ trigger.to_state.name }}'),
    );
  });

  testWidgets('More → Batteries: emptiest first, reminder saved in HA', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);

    await tapKey(tester, 'openExtras');
    await settle(tester, 2);
    await tapKey(tester, 'extraBatteries');
    await settle(tester, 3);
    expect(find.byKey(const Key('batteriesSheet')), findsOneWidget);
    final first = container.read(batteriesProvider).first;
    expect(first.percent, 8);
    expect(first.low, isTrue);
    expect(first.sensorId, 'sensor.bedroom_window_battery');
    expect(find.text('8 %'), findsOneWidget);

    await tapKey(tester, 'batteryReminder');
    await settle(tester, 4);
    expect(server.automations[batteryReminderId], isNotNull);
    expect(container.read(batteryReminderSetProvider), isTrue);
    expect(find.text(en.batteryReminder), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a reminder saved with old sensors is brought up to date', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    server.saveAutomation(
      batteryReminderId,
      batteryReminderAutomation(
        AppLocalizationsEn(),
        sensorIds: ['sensor.gone_battery'],
        notify: const [],
      ),
    );
    await settle(tester, 3);
    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraBatteries');
    await settle(tester, 15);
    final trigger =
        (server.automations[batteryReminderId]!['triggers']! as List).first
            as Map;
    expect(trigger['entity_id'], ['sensor.bedroom_window_battery']);
    await unmount(tester);
  });
}
