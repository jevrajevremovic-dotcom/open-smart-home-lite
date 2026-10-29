import 'package:flutter/foundation.dart';

/// Home Assistant Energy configuration (WS `energy/get_prefs`): which
/// long-term statistics represent grid import/export, solar, battery and
/// gas, and which ones are individual devices.
///
/// The command is used by the official frontend's Energy dashboard but is
/// not listed in the developer docs, so parsing is defensive and the whole
/// feature degrades to "not configured" when it fails.
@immutable
class EnergyPrefs {
  const EnergyPrefs({
    this.gridImport = const [],
    this.gridExport = const [],
    this.solar = const [],
    this.batteryCharge = const [],
    this.batteryDischarge = const [],
    this.gas = const [],
    this.devices = const [],
  });

  static EnergyPrefs? tryParse(Object? json) {
    if (json is! Map) return null;
    final gridImport = <String>[];
    final gridExport = <String>[];
    final solar = <String>[];
    final charge = <String>[];
    final discharge = <String>[];
    final gas = <String>[];
    String? id(Object? v) => v is String && v.isNotEmpty ? v : null;

    for (final source
        in (json['energy_sources'] is List
            ? json['energy_sources'] as List
            : const [])) {
      if (source is! Map) continue;
      switch (source['type']) {
        case 'grid':
          for (final f
              in (source['flow_from'] is List
                  ? source['flow_from'] as List
                  : const [])) {
            if (f is Map) gridImport.addAll([?id(f['stat_energy_from'])]);
          }
          for (final f
              in (source['flow_to'] is List
                  ? source['flow_to'] as List
                  : const [])) {
            if (f is Map) gridExport.addAll([?id(f['stat_energy_to'])]);
          }
        case 'solar':
          solar.addAll([?id(source['stat_energy_from'])]);
        case 'battery':
          // From the home's view: energy *from* the battery is discharge.
          discharge.addAll([?id(source['stat_energy_from'])]);
          charge.addAll([?id(source['stat_energy_to'])]);
        case 'gas':
          gas.addAll([?id(source['stat_energy_from'])]);
      }
    }
    final devices = <EnergyDevice>[
      for (final d
          in (json['device_consumption'] is List
              ? json['device_consumption'] as List
              : const []))
        if (d is Map && id(d['stat_consumption']) != null)
          EnergyDevice(
            statisticId: d['stat_consumption'] as String,
            name: id(d['name']),
          ),
    ];
    return EnergyPrefs(
      gridImport: gridImport,
      gridExport: gridExport,
      solar: solar,
      batteryCharge: charge,
      batteryDischarge: discharge,
      gas: gas,
      devices: devices,
    );
  }

  final List<String> gridImport;
  final List<String> gridExport;
  final List<String> solar;
  final List<String> batteryCharge;
  final List<String> batteryDischarge;
  final List<String> gas;
  final List<EnergyDevice> devices;

  /// Electricity sources configured (gas alone is not enough for the
  /// consumption figure).
  bool get hasElectricity => gridImport.isNotEmpty || solar.isNotEmpty;

  bool get isEmpty => !hasElectricity && gas.isEmpty && devices.isEmpty;

  Set<String> get electricityStatistics => {
    ...gridImport,
    ...gridExport,
    ...solar,
    ...batteryCharge,
    ...batteryDischarge,
    for (final d in devices) d.statisticId,
  };
}

@immutable
class EnergyDevice {
  const EnergyDevice({required this.statisticId, this.name});

  final String statisticId;

  /// Optional display name from the Energy configuration.
  final String? name;
}

/// One bucket of `recorder/statistics_during_period` with `types: [change]`.
@immutable
class StatisticChange {
  const StatisticChange(this.start, this.change);

  final DateTime start;
  final double change;
}

/// Parses the statistics response: `{statistic_id: [{start, change, …}]}`.
/// `start` is epoch milliseconds in current Home Assistant and an ISO string
/// in older versions; both are accepted. Malformed rows are skipped.
Map<String, List<StatisticChange>> parseStatistics(Object? json) {
  if (json is! Map) return const {};
  final result = <String, List<StatisticChange>>{};
  for (final entry in json.entries) {
    final rows = entry.value;
    if (entry.key is! String || rows is! List) continue;
    final parsed = <StatisticChange>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final start = switch (row['start']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(
          ms.toInt(),
          isUtc: true,
        ),
        final String iso => DateTime.tryParse(iso),
        _ => null,
      };
      final change = row['change'];
      if (start != null && change is num && change.isFinite) {
        parsed.add(StatisticChange(start.toLocal(), change.toDouble()));
      }
    }
    result[entry.key as String] = parsed;
  }
  return result;
}
