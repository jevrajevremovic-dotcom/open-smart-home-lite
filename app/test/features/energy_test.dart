import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/features/energy/presentation/energy_chart.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/energy/data/energy_repository.dart';
import 'package:open_smart_home_lite/features/energy/data/tariff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/energy/ha_energy.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_fixtures.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/mock/mock_home_assistant.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/backoff.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/connection_status.dart';
import 'package:open_smart_home_lite/integrations/home_assistant/websocket/ha_websocket_manager.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, tapKey, unmount;

void main() {
  group('EnergyPrefs', () {
    test('parses all source types and devices', () {
      final p = EnergyPrefs.tryParse({
        'energy_sources': [
          {
            'type': 'grid',
            'flow_from': [
              {'stat_energy_from': 'sensor.import'},
            ],
            'flow_to': [
              {'stat_energy_to': 'sensor.export'},
            ],
          },
          {'type': 'solar', 'stat_energy_from': 'sensor.pv'},
          {
            'type': 'battery',
            'stat_energy_from': 'sensor.bat_out',
            'stat_energy_to': 'sensor.bat_in',
          },
          {'type': 'gas', 'stat_energy_from': 'sensor.gas'},
          {'type': 'water', 'stat_energy_from': 'sensor.water'},
          'garbage',
        ],
        'device_consumption': [
          {'stat_consumption': 'sensor.dishwasher', 'name': 'Sudomašina'},
          {'stat_consumption': 'sensor.fridge'},
          {'name': 'missing id'},
        ],
      })!;
      expect(p.gridImport, ['sensor.import']);
      expect(p.gridExport, ['sensor.export']);
      expect(p.solar, ['sensor.pv']);
      expect(p.batteryDischarge, ['sensor.bat_out']);
      expect(p.batteryCharge, ['sensor.bat_in']);
      expect(p.gas, ['sensor.gas']);
      expect(p.devices.map((d) => (d.statisticId, d.name)), [
        ('sensor.dishwasher', 'Sudomašina'),
        ('sensor.fridge', null),
      ]);
    });

    test('garbage and empty configs', () {
      expect(EnergyPrefs.tryParse('x'), isNull);
      expect(EnergyPrefs.tryParse({})!.isEmpty, isTrue);
    });
  });

  test('statistics: epoch ms and ISO starts, malformed rows skipped', () {
    final s = parseStatistics({
      'sensor.a': [
        {
          'start': DateTime.utc(2026, 10, 13, 10).millisecondsSinceEpoch,
          'change': 1.5,
        },
        {'start': '2026-10-13T11:00:00+00:00', 'change': 2},
        {'start': 'nope', 'change': 1},
        {'start': 0, 'change': 'x'},
      ],
      'sensor.b': 'garbage',
    });
    expect(s['sensor.a']!.map((r) => r.change), [1.5, 2.0]);
    expect(
      s['sensor.a']!.first.start,
      DateTime.utc(2026, 10, 13, 10).toLocal(),
    );
    expect(s.containsKey('sensor.b'), isFalse);
  });

  group('EnergyRange', () {
    final wednesday = DateTime(2026, 10, 14, 15, 30);

    test('today: 24 hourly slots', () {
      expect(EnergyRange.today.bounds(wednesday), (
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 15),
      ));
      expect(EnergyRange.today.slots(wednesday), hasLength(24));
    });

    test('week starts on Monday', () {
      expect(EnergyRange.week.bounds(wednesday).$1, DateTime(2026, 10, 12));
      expect(EnergyRange.week.slots(wednesday), hasLength(7));
    });

    test('month has its real number of days', () {
      expect(EnergyRange.month.slots(DateTime(2026, 2, 10)), hasLength(28));
      expect(EnergyRange.month.slots(wednesday), hasLength(31));
    });
  });

  test('two-rate meter: hours across midnight, next change, cost', () {
    const low = LowTariff(fromHour: 23, toHour: 7, price: 5);
    expect(low.hours, {23, 0, 1, 2, 3, 4, 5, 6});
    expect(low.containsHour(7), isFalse);
    expect(low.containsHour(22), isFalse);
    expect(
      low.nextChange(DateTime(2026, 10, 16, 2, 30)),
      DateTime(2026, 10, 16, 7),
    );
    expect(
      low.nextChange(DateTime(2026, 10, 16, 12)),
      DateTime(2026, 10, 16, 23),
    );
    expect(
      low.nextChange(DateTime(2026, 10, 16, 23, 10)),
      DateTime(2026, 10, 17, 7),
    );
    const belgrade = LowTariff(fromHour: 0, toHour: 8, price: 5);
    expect(belgrade.hours, {0, 1, 2, 3, 4, 5, 6, 7});

    const tariff = Tariff(importPrice: 15, low: low);
    // 10 kWh, 4 of them at night: 6 × 15 + 4 × 5.
    expect(tariff.estimate(gridImport: 10, gridImportLow: 4), 110);
    final again = Tariff.tryFromJson(tariff.toJson())!;
    expect(again.low, low);
    expect(
      LowTariff.tryFromJson({'fromHour': 5, 'toHour': 5, 'price': 1}),
      isNull,
      reason: 'an empty window',
    );
    expect(Tariff.tryFromJson({'importPrice': 15})!.low, isNull);
  });

  test('tariff estimate and storage', () {
    const t = Tariff(importPrice: 12.5, exportPrice: 5);
    expect(t.estimate(gridImport: 10, gridExport: 2), 115);
    expect(t.estimate(gridImport: null), isNull);
    expect(Tariff.tryFromJson(t.toJson())!.exportPrice, 5);
    expect(Tariff.tryFromJson({'importPrice': -1}), isNull);
  });

  group('EnergyRepository against the mock server', () {
    late MockHomeAssistantServer server;
    late HaWebSocketManager ws;

    setUp(() async {
      server = MockHomeAssistantServer();
      ws = HaWebSocketManager(
        uri: Uri.parse('ws://ha.local/api/websocket'),
        readToken: () async => 't',
        connector: server.connect,
        backoff: ExponentialBackoff(random: Random(1)),
      );
      ws.connect();
      await ws.statusStream.firstWhere(
        (s) => s.state == HaConnectionState.connected,
      );
    });
    tearDown(() => ws.dispose());

    test('consumption = import + solar − export, per hour', () async {
      final repo = EnergyRepository(ws);
      final prefs = (await repo.loadPrefs())!;
      final now = DateTime.now();
      final report = await repo.loadReport(prefs, EnergyRange.today, now: now);

      var expected = 0.0;
      for (
        var h = DateTime(now.year, now.month, now.day);
        h.isBefore(now);
        h = h.add(const Duration(hours: 1))
      ) {
        double r(String id) =>
            double.parse(mockHourlyEnergy(id, h).toStringAsFixed(3));
        expected += max(
          0,
          r('sensor.house_energy') +
              r('sensor.solar_energy') -
              r('sensor.grid_export_energy'),
        );
      }
      expect(report.consumption, closeTo(expected, 0.01));
      expect(report.buckets, hasLength(24));
      // Hours that have not started yet are "no data", not 0. (Between
      // 23:00 and midnight there is no such hour left today.)
      for (final b in report.buckets.where((b) => b.start.isAfter(now))) {
        expect(b.consumption, isNull, reason: '${b.start}');
      }
      expect(report.gas, isNull, reason: 'gas is not configured');
      expect(report.solar, isNotNull);
    });

    for (final range in [EnergyRange.today, EnergyRange.week]) {
      test('two-rate split of grid import (${range.name})', () async {
        final repo = EnergyRepository(ws);
        final prefs = (await repo.loadPrefs())!;
        final now = DateTime.now();
        final night = {0, 1, 2, 3, 4, 5, 6, 7};
        final report = await repo.loadReport(
          prefs,
          range,
          now: now,
          lowHours: night,
        );
        final (start, _) = range.bounds(now);
        var expected = 0.0;
        for (
          var h = start;
          h.isBefore(now);
          h = h.add(const Duration(hours: 1))
        ) {
          if (!night.contains(h.hour)) continue;
          expected += double.parse(
            mockHourlyEnergy('sensor.house_energy', h).toStringAsFixed(3),
          );
        }
        expect(report.gridImportLow, closeTo(expected, 0.01));
        expect(report.gridImportLow, lessThanOrEqualTo(report.gridImport!));
      });
    }

    test(
      'devices are named from the configuration and sorted by energy',
      () async {
        final repo = EnergyRepository(ws);
        final prefs = (await repo.loadPrefs())!;
        final report = await repo.loadReport(
          prefs,
          EnergyRange.month,
          now: DateTime.now(),
        );
        final kwh = report.devices.map((d) => d.kwh).toList();
        expect(kwh, [...kwh]..sort((a, b) => b.compareTo(a)));
        expect(
          report.devices.map((d) => d.name),
          contains('Klima dnevna soba'),
        );
      },
    );

    test('Energy not configured → null (no invented numbers)', () async {
      server.energyPrefs = null;
      expect(await EnergyRepository(ws).loadPrefs(), isNull);
    });
  });

  group('Energy screen', () {
    testWidgets(
      'shows totals, chart/table and top consumers; tariff adds a cost estimate',
      (tester) async {
        await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
        await settle(tester, 10);
        await goTo(tester, AppRoutes.energy);
        await settle(tester, 6);

        expect(find.text(en.energyConsumption), findsOneWidget);
        expect(
          find.textContaining(en.energyPrevDay('').trim()),
          findsOneWidget,
        );
        expect(find.text(en.energySolar), findsOneWidget);
        expect(
          find.text(en.energyGas),
          findsNothing,
          reason: 'not configured → not shown',
        );
        expect(find.text(en.energyTopConsumers), findsOneWidget);

        await tapKey(tester, 'energyTableToggle');
        await settle(tester, 2);
        expect(find.text(en.energyShowChart), findsOneWidget);

        expect(find.byKey(const Key('energyCost')), findsNothing);
        await tapKey(tester, 'energySetTariff');
        await settle(tester, 3);
        await tester.enterText(find.byKey(const Key('tariffImport')), '12,5');
        await tapKey(tester, 'tariffSave');
        await settle(tester, 3);
        expect(find.byKey(const Key('energyCost')), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('a top consumer opens its own chart', (tester) async {
      await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
      await settle(tester, 10);
      await goTo(tester, AppRoutes.energy);
      await settle(tester, 6);
      await tapKey(tester, 'energyDevice-sensor.ac_energy');
      await settle(tester, 4);
      final sheet = find.byKey(const Key('energyDeviceSheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Klima dnevna soba')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(ConsumptionChart)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('%')),
        findsWidgets,
      );
      await unmount(tester);
    });

    testWidgets('week and month ranges load', (tester) async {
      await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
      await settle(tester, 10);
      await goTo(tester, AppRoutes.energy);
      await settle(tester, 6);
      await tester.tap(find.text(en.energyMonth));
      await settle(tester, 6);
      expect(find.text(en.energyPerDay), findsOneWidget);
      expect(
        find.textContaining(en.energyPrevMonth('').trim()),
        findsOneWidget,
        reason: 'previous month shown for comparison',
      );
      await unmount(tester);
    });

    testWidgets('two-rate meter: rate now, high/low split, shaded hours', (
      tester,
    ) async {
      await pumpApp(tester, signedIn: true, size: const Size(800, 1600));
      await settle(tester, 10);
      await goTo(tester, AppRoutes.energy);
      await settle(tester, 6);
      await tapKey(tester, 'energySetTariff');
      await settle(tester, 3);
      await tester.enterText(find.byKey(const Key('tariffImport')), '15');
      await tapKey(tester, 'tariffTwoRate');
      await settle(tester, 2);
      await tester.enterText(find.byKey(const Key('tariffLowPrice')), '7');
      await tapKey(tester, 'tariffPreset-23');
      await settle(tester, 2);
      await tapKey(tester, 'tariffSave');
      await settle(tester, 6);

      expect(find.byKey(const Key('energyRateNow')), findsOneWidget);
      expect(find.byKey(const Key('energyHighRate')), findsOneWidget);
      expect(find.byKey(const Key('energyLowRate')), findsOneWidget);
      expect(find.byKey(const Key('energyLowLegend')), findsOneWidget);
      expect(find.byKey(const Key('energyCost')), findsOneWidget);
      await unmount(tester);
    });
  });
}
