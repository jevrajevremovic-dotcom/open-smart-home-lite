import 'package:flutter/foundation.dart';

/// The lower (night) rate of a two-rate meter: whole hours, local time,
/// [fromHour] inclusive to [toHour] exclusive, wrapping past midnight
/// (23 → 7). Hours differ by distribution area, so the user enters them.
@immutable
class LowTariff {
  const LowTariff({
    required this.fromHour,
    required this.toHour,
    required this.price,
  });

  static LowTariff? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final from = json['fromHour'];
    final to = json['toHour'];
    final price = json['price'];
    if (from is! int || to is! int || price is! num || price < 0) return null;
    if (from < 0 || from > 23 || to < 0 || to > 23 || from == to) return null;
    return LowTariff(fromHour: from, toHour: to, price: price.toDouble());
  }

  final int fromHour;
  final int toHour;

  /// Price per kWh in these hours.
  final double price;

  bool containsHour(int hour) => fromHour < toHour
      ? hour >= fromHour && hour < toHour
      : hour >= fromHour || hour < toHour;

  Set<int> get hours => {
    for (var h = 0; h < 24; h++)
      if (containsHour(h)) h,
  };

  /// When the current rate ends: the next start or end of the low hours.
  DateTime nextChange(DateTime now) {
    final edge = containsHour(now.hour) ? toHour : fromHour;
    var at = DateTime(now.year, now.month, now.day, edge);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, edge);
    return at;
  }

  Map<String, Object?> toJson() => {
    'fromHour': fromHour,
    'toHour': toHour,
    'price': price,
  };

  @override
  bool operator ==(Object other) =>
      other is LowTariff &&
      other.fromHour == fromHour &&
      other.toHour == toHour &&
      other.price == price;

  @override
  int get hashCode => Object.hash(fromHour, toHour, price);
}

/// Electricity price entered by the user, used only for a clearly labelled
/// cost *estimate* (real bills include fixed fees, taxes, zones…).
@immutable
class Tariff {
  const Tariff({
    required this.importPrice,
    this.exportPrice,
    this.currency = 'RSD',
    this.low,
  });

  static Tariff? tryFromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final import = json['importPrice'];
    if (import is! num || import < 0) return null;
    final export = json['exportPrice'];
    final currency = json['currency'];
    return Tariff(
      importPrice: import.toDouble(),
      exportPrice: export is num && export >= 0 ? export.toDouble() : null,
      currency: currency is String && currency.isNotEmpty ? currency : 'RSD',
      low: LowTariff.tryFromJson(json['low']),
    );
  }

  /// Price per kWh taken from the grid (the higher rate with [low]).
  final double importPrice;

  /// Two-rate meter: the cheaper night hours.
  final LowTariff? low;

  /// Compensation per kWh returned to the grid, if any.
  final double? exportPrice;
  final String currency;

  /// `null` when the grid import is unknown. With [low], [gridImportLow]
  /// (kWh taken in the low hours) is charged at the lower price.
  double? estimate({
    required double? gridImport,
    double? gridExport,
    double? gridImportLow,
  }) {
    if (gridImport == null) return null;
    final lowKwh = low == null ? 0.0 : (gridImportLow ?? 0.0);
    return (gridImport - lowKwh) * importPrice +
        lowKwh * (low?.price ?? 0) -
        (gridExport ?? 0) * (exportPrice ?? 0);
  }

  Map<String, Object?> toJson() => {
    'importPrice': importPrice,
    'exportPrice': exportPrice,
    'currency': currency,
    if (low != null) 'low': low!.toJson(),
  };
}
