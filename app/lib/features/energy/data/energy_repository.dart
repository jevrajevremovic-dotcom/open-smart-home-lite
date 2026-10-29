import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../integrations/home_assistant/energy/ha_energy.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';

enum EnergyRange {
  today,
  week,
  month;

  /// Start (inclusive) and end (exclusive) in local time.
  (DateTime, DateTime) bounds(DateTime now) => switch (this) {
    today => (
      DateTime(now.year, now.month, now.day),
      DateTime(now.year, now.month, now.day + 1),
    ),
    // ISO week: Monday to Monday.
    week => (
      DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      DateTime(now.year, now.month, now.day - (now.weekday - 1) + 7),
    ),
    month => (DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
  };

  /// Statistics period: hourly buckets for a day, daily otherwise.
  String get period => this == today ? 'hour' : 'day';

  List<DateTime> slots(DateTime now) {
    final (start, end) = bounds(now);
    return [
      for (
        var t = start;
        t.isBefore(end);
        t = this == today
            ? t.add(const Duration(hours: 1))
            : DateTime(t.year, t.month, t.day + 1)
      )
        t,
    ];
  }
}

/// Consumption of one time slot; `null` = no data (future or not recorded),
/// which is shown as missing, never as zero.
@immutable
class EnergyBucket {
  const EnergyBucket(this.start, this.consumption);

  final DateTime start;
  final double? consumption;
}

@immutable
class DeviceEnergy {
  const DeviceEnergy({
    required this.statisticId,
    required this.name,
    required this.kwh,
    this.buckets = const [],
  });

  final String statisticId;
  final String name;
  final double kwh;

  /// The device's own consumption per slot of the range (`null` = no data).
  final List<EnergyBucket> buckets;
}

/// Totals for one range. A `null` total means that source is not configured
/// in Home Assistant's Energy settings (different from a measured 0).
@immutable
class EnergyReport {
  const EnergyReport({
    required this.range,
    required this.buckets,
    required this.consumption,
    required this.gridImport,
    required this.devices,
    this.gridExport,
    this.solar,
    this.batteryCharge,
    this.batteryDischarge,
    this.gas,
    this.gridImportLow,
  });

  final EnergyRange range;
  final List<EnergyBucket> buckets;

  /// kWh: grid import + solar − grid export − battery charge + battery
  /// discharge (Home Assistant's definition of home consumption).
  final double? consumption;
  final double? gridImport;

  /// kWh taken from the grid in the low-rate hours (two-rate meter);
  /// `null` when not asked for or unknown.
  final double? gridImportLow;
  final double? gridExport;
  final double? solar;
  final double? batteryCharge;
  final double? batteryDischarge;

  /// m³ (or the gas statistic's own unit).
  final double? gas;

  /// Sorted by consumption, largest first.
  final List<DeviceEnergy> devices;
}

/// Loads Home Assistant's long-term statistics for the Energy dashboard.
class EnergyRepository {
  EnergyRepository(this._ws);

  final HaWebSocketManager _ws;
  static final _log = AppLogger('Energy');

  /// `null` when Energy is not configured (HA answers `not_found`) or the
  /// command is not available on this server/user.
  Future<EnergyPrefs?> loadPrefs() async {
    try {
      final prefs = EnergyPrefs.tryParse(
        await _ws.sendCommand({'type': 'energy/get_prefs'}),
      );
      return prefs == null || prefs.isEmpty ? null : prefs;
    } on AppFailure catch (e) {
      if (e.isTransient) rethrow;
      _log.info('Energy preferences unavailable: ${e.kind.name}');
      return null;
    }
  }

  Future<EnergyReport> loadReport(
    EnergyPrefs prefs,
    EnergyRange range, {
    required DateTime now,
    String Function(String statisticId)? nameOf,
    Set<int>? lowHours,
  }) async {
    final (start, end) = range.bounds(now);
    final ids = {...prefs.electricityStatistics, ...prefs.gas};
    final stats = parseStatistics(
      await _ws.sendCommand({
        'type': 'recorder/statistics_during_period',
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
        'statistic_ids': ids.toList(),
        'period': range.period,
        'types': ['change'],
        'units': {'energy': 'kWh', 'volume': 'm³'},
      }),
    );

    // Per-slot sums for a group of statistics; `null` if none reported.
    Map<DateTime, double> bySlot(List<String> group) {
      final out = <DateTime, double>{};
      for (final id in group) {
        for (final row in stats[id] ?? const <StatisticChange>[]) {
          out.update(
            row.start,
            (v) => v + row.change,
            ifAbsent: () => row.change,
          );
        }
      }
      return out;
    }

    double? total(List<String> group) {
      if (group.isEmpty) return null;
      final values = bySlot(group).values;
      return values.fold<double>(0, (a, b) => a + b);
    }

    final import = bySlot(prefs.gridImport);
    final export = bySlot(prefs.gridExport);
    final solar = bySlot(prefs.solar);
    final charge = bySlot(prefs.batteryCharge);
    final discharge = bySlot(prefs.batteryDischarge);
    final reported = {...import.keys, ...solar.keys};

    double slotConsumption(DateTime t) => [
      (import[t] ?? 0) +
          (solar[t] ?? 0) -
          (export[t] ?? 0) -
          (charge[t] ?? 0) +
          (discharge[t] ?? 0),
      0.0,
    ].reduce((a, b) => a > b ? a : b); // meter timing can briefly go negative

    final buckets = [
      for (final slot in range.slots(now))
        EnergyBucket(
          slot,
          reported.contains(slot) ? slotConsumption(slot) : null,
        ),
    ];
    final consumption = prefs.hasElectricity
        ? buckets
              .map((b) => b.consumption ?? 0)
              .fold<double>(0, (a, b) => a + b)
        : null;

    List<EnergyBucket> series(String statisticId) {
      final perSlot = bySlot([statisticId]);
      return [
        for (final slot in range.slots(now)) EnergyBucket(slot, perSlot[slot]),
      ];
    }

    final devices = [
      for (final d in prefs.devices)
        if (stats[d.statisticId] case final rows? when rows.isNotEmpty)
          DeviceEnergy(
            statisticId: d.statisticId,
            name: d.name ?? nameOf?.call(d.statisticId) ?? d.statisticId,
            kwh: rows.fold<double>(0, (a, r) => a + r.change),
            buckets: series(d.statisticId),
          ),
    ]..sort((a, b) => b.kwh.compareTo(a.kwh));

    // Two-rate meter: grid import in the low hours. Days need the hourly
    // statistics of the grid meters (one more request, only then).
    double? importLow;
    if (lowHours != null && prefs.gridImport.isNotEmpty) {
      final hourly = range.period == 'hour'
          ? import
          : _sumBySlot(
              parseStatistics(
                await _ws.sendCommand({
                  'type': 'recorder/statistics_during_period',
                  'start_time': start.toUtc().toIso8601String(),
                  'end_time': end.toUtc().toIso8601String(),
                  'statistic_ids': prefs.gridImport,
                  'period': 'hour',
                  'types': ['change'],
                  'units': {'energy': 'kWh'},
                }),
              ),
              prefs.gridImport,
            );
      importLow = hourly.entries
          .where((e) => lowHours.contains(e.key.toLocal().hour))
          .fold<double>(0, (a, e) => a + e.value);
    }

    return EnergyReport(
      range: range,
      gridImportLow: importLow,
      buckets: buckets,
      consumption: consumption,
      gridImport: total(prefs.gridImport),
      gridExport: total(prefs.gridExport),
      solar: total(prefs.solar),
      batteryCharge: total(prefs.batteryCharge),
      batteryDischarge: total(prefs.batteryDischarge),
      gas: total(prefs.gas),
      devices: devices,
    );
  }
}

Map<DateTime, double> _sumBySlot(
  Map<String, List<StatisticChange>> stats,
  List<String> group,
) {
  final out = <DateTime, double>{};
  for (final id in group) {
    for (final row in stats[id] ?? const <StatisticChange>[]) {
      out.update(row.start, (v) => v + row.change, ifAbsent: () => row.change);
    }
  }
  return out;
}
