import 'package:open_smart_home_lite/features/devices/presentation/device_history.dart';
import 'package:open_smart_home_lite/features/devices/domain/device_kind.dart';
import 'package:open_smart_home_lite/app/localization/generated/app_localizations_sr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_history.dart';

import '../integrations/home_assistant_api_test.dart' show build;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, unmount;

void main() {
  test('sensor states read as what they mean', () {
    final l10n = AppLocalizationsSrLatn();
    expect(
      historyStateLabel(l10n, 'on', DeviceKind.contactSensor),
      l10n.contactOpen,
    );
    expect(
      historyStateLabel(l10n, 'off', DeviceKind.motionSensor),
      l10n.motionClear,
    );
    expect(historyStateLabel(l10n, 'on', DeviceKind.light), l10n.stateOn);
    expect(historyStateLabel(l10n, 'on'), l10n.stateOn);
    expect(historyStateLabel(l10n, 'locked'), l10n.lockLocked);
  });

  test('history and logbook parsing', () {
    final h = HaHistoryPoint.parse([
      [
        {
          'entity_id': 'sensor.t',
          'state': '21.5',
          'last_changed': '2026-10-13T10:00:00+00:00',
        },
        {'state': '22.0', 'last_changed': '2026-10-13T10:30:00+00:00'},
        {'state': 'x'},
      ],
    ]);
    expect(h.map((p) => p.state), ['21.5', '22.0']);
    expect(HaHistoryPoint.parse([]), isEmpty);
    final log = HaLogbookEntry.parse([
      {'when': '2026-10-13T08:00:00+00:00', 'state': 'off'},
      {
        'when': '2026-10-13T09:00:00+00:00',
        'state': 'on',
        'context_user_id': 'u1',
      },
    ]);
    expect(log.first.state, 'on', reason: 'newest first');
    expect(log.first.byUser, isTrue);
  });

  test('REST history path, query and validation', () async {
    final (api, adapter) = build((_) => (200, [<Object?>[]]));
    await api.fetchHistory(
      'sensor.living_room_temperature',
      DateTime.utc(2026, 10, 12, 10),
      DateTime.utc(2026, 10, 13, 10),
    );
    final uri = adapter.requests.single.uri;
    expect(uri.path, '/api/history/period/2026-10-12T10:00:00.000Z');
    expect(
      uri.queryParameters['filter_entity_id'],
      'sensor.living_room_temperature',
    );
    expect(uri.queryParameters.containsKey('minimal_response'), isTrue);
    expect(
      () => api.fetchHistory('../x', DateTime(2026), DateTime(2026)),
      throwsA(anything),
    );
  });

  testWidgets('sensor chart with scrubbing; light timeline and activity', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.device('sensor.living_room_temperature'));
    await settle(tester, 6);
    final chart = find.byKey(const Key('historyChart'));
    expect(chart, findsOneWidget);
    final caption = find.byKey(const Key('historyCaption'));
    expect(
      tester.widget<Text>(caption).data,
      contains(en.historyMin('').trim()),
    );
    final gesture = await tester.startGesture(tester.getCenter(chart));
    await tester.pump();
    expect(
      tester.widget<Text>(caption).data,
      isNot(contains(en.historyMin('').trim())),
      reason: 'scrubbing shows one value',
    );
    await gesture.up();
    await tester.tap(find.text(en.history7d));
    await settle(tester, 6);
    expect(chart, findsOneWidget);

    await goTo(tester, AppRoutes.device('light.living_room_main'));
    await settle(tester, 6);
    expect(find.byKey(const Key('historyTimeline')), findsOneWidget);
    expect(find.byKey(const Key('activityList')), findsOneWidget);
    await unmount(tester);
  });
}
