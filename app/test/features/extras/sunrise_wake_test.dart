import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_en.dart';
import 'package:open_smart_home_lite/features/automations/domain/simple_automation.dart';
import 'package:open_smart_home_lite/features/extras/sunrise_wake.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/home_assistant_providers.dart';

import '../../widgets/app_widget_test.dart'
    show pumpApp, settle, tapKey, unmount;

void main() {
  test('starts the length of the sunrise before waking, same days', () {
    const w = SunriseWake(
      lights: ['light.bed'],
      wakeAt: ClockTime(6, 30),
      minutes: 20,
      days: {'mon', 'fri'},
    );
    final c = w.automation(AppLocalizationsEn(), const {});
    expect(c['triggers'], [
      {'trigger': 'time', 'at': '06:10:00'},
    ]);
    expect(c['conditions'], [
      {
        'condition': 'time',
        'weekday': ['mon', 'fri'],
      },
    ]);
    final last = (c['actions']! as List).last as Map;
    expect((last['data']! as Map)['transition'], 20 * 60);
    expect(SunriseWake.fromAutomation(c)!.days, {'mon', 'fri'});
  });

  test('a sunrise starting before midnight moves to the day before', () {
    const w = SunriseWake(
      lights: ['light.bed'],
      wakeAt: ClockTime(0, 10),
      minutes: 15,
      days: {'mon'},
    );
    final (at, days) = w.start;
    expect(at, const ClockTime(23, 55));
    expect(days, ['sun']);
  });

  testWidgets('More → Sunrise alarm: saved as an HA automation', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SmartHomeApp)),
    );
    final server = container.read(mockHomeAssistantServerProvider);
    await tapKey(tester, 'openExtras');
    await settle(tester, 5);
    await tapKey(tester, 'extraSunrise');
    await settle(tester, 4);
    // Pick the first light if no bedroom light was preselected.
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('sunriseSave')),
    );
    if (save.onPressed == null) {
      await tester.tap(find.byType(CheckboxListTile).first);
      await settle(tester);
    }
    await tapKey(tester, 'sunriseSave');
    await settle(tester, 4);
    expect(server.automations[sunriseWakeId], isNotNull);
    expect(container.read(sunriseWakeSetProvider), isTrue);
    await unmount(tester);
  });
}
