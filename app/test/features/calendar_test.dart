import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/core/errors/app_failure.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/models/ha_calendar.dart';

import '../integrations/home_assistant_api_test.dart' show build;
import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  group('calendar parsing', () {
    test('calendars list', () {
      final list = HaCalendar.parseList([
        {'entity_id': 'calendar.a', 'name': 'A'},
        {'entity_id': 'calendar.b'},
        {'name': 'no id'},
      ]);
      expect([for (final c in list) c.name], ['A', 'calendar.b']);
    });

    test('timed and all-day events (exclusive end date)', () {
      final events = HaCalendarEvent.parseList([
        {
          'summary': 'Meeting',
          'start': {'dateTime': '2026-10-13T09:00:00+02:00'},
          'end': {'dateTime': '2026-10-13T11:00:00+02:00'},
          'location': ' Office ',
        },
        {
          'summary': 'Trip',
          'start': {'date': '2026-10-14'},
          'end': {'date': '2026-10-16'},
        },
        {'summary': 'broken'},
      ], 'calendar.a');
      expect(events, hasLength(2));
      final meeting = events.first;
      expect(meeting.allDay, isFalse);
      expect(
        meeting.start.toUtc(),
        DateTime.utc(2026, 10, 13, 7),
        reason: 'offset respected',
      );
      expect(meeting.location, 'Office');
      final trip = events.last;
      expect(trip.allDay, isTrue);
      expect(trip.occursOn(DateTime(2026, 10, 14)), isTrue);
      expect(trip.occursOn(DateTime(2026, 10, 15, 23)), isTrue);
      expect(
        trip.occursOn(DateTime(2026, 10, 16)),
        isFalse,
        reason: 'end date is exclusive',
      );
      expect(trip.occursOn(DateTime(2026, 10, 13)), isFalse);
    });
  });

  test(
    'REST: GET /api/calendars/<id> with start and end; id validated',
    () async {
      final (api, adapter) = build(
        (o) => (
          200,
          [
            {
              'summary': 'X',
              'start': {'date': '2026-10-13'},
              'end': {'date': '2026-10-14'},
            },
          ],
        ),
      );
      final events = await api.fetchCalendarEvents(
        'calendar.family',
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 11, 1),
      );
      expect(events.single.summary, 'X');
      final r = adapter.requests.single;
      expect(r.uri.path, '/api/calendars/calendar.family');
      expect(r.uri.queryParameters['start'], '2026-10-01T00:00:00.000Z');
      expect(r.uri.queryParameters['end'], '2026-11-01T00:00:00.000Z');
      expect(r.headers['Authorization'], 'Bearer good-token');
      await expectLater(
        api.fetchCalendarEvents('../states', DateTime(2026), DateTime(2027)),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  testWidgets('calendar screen: today, other days, month navigation', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true, size: const Size(1200, 900));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.calendar);
    await settle(tester, 6);
    expect(find.text(en.calendarTitle), findsWidgets);
    expect(find.text(en.calendarToday.toUpperCase()), findsOneWidget);
    expect(find.text('Vrtić'), findsOneWidget);
    expect(find.text('Sastanak tima'), findsOneWidget);
    expect(find.text('Rođendan – Ana'), findsOneWidget, reason: 'tomorrow');

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (tomorrow.month == DateTime.now().month) {
      await tester.tap(
        find.byKey(ValueKey('calDay-${tomorrow.month}-${tomorrow.day}')),
      );
      await settle(tester, 2);
      expect(find.text(en.calendarToday.toUpperCase()), findsNothing);
      expect(find.text(en.calendarTomorrow.toUpperCase()), findsOneWidget);
      expect(find.textContaining(en.calendarAllDay), findsWidgets);
    }

    final title = tester.widget<Text>(find.byKey(const Key('calMonthTitle')));
    await tapKey(tester, 'calNextMonth');
    await settle(tester, 4);
    expect(
      tester.widget<Text>(find.byKey(const Key('calMonthTitle'))).data,
      isNot(title.data),
    );
    await unmount(tester);
  });

  testWidgets('the kiosk home shows the calendar', (tester) async {
    await pumpApp(tester, signedIn: true, size: const Size(1600, 1000));
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('kiosk'));
    await tapKey(tester, 'startKiosk');
    await settle(tester, 20);
    final calendar = find.byKey(const Key('kioskColumnsCalendar'));
    await tester.scrollUntilVisible(
      calendar,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('kioskColumnsOverview')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Built only now (the overview is lazy): let its events load.
    await settle(tester, 10);
    expect(
      find.descendant(of: calendar, matching: find.text('Vrtić')),
      findsWidgets,
    );
    await unmount(tester);
  });
}
