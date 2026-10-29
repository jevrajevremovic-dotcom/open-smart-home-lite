import 'package:intl/intl.dart';

/// kWh with precision that suits the magnitude: 0,07 · 3,42 · 128,5 · 1.284.
String formatKwh(String locale, double kwh) {
  final format = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = kwh.abs() < 10
        ? 2
        : kwh.abs() < 1000
        ? 1
        : 0;
  return '${format.format(kwh)} kWh';
}

String formatMoney(String locale, double amount, String currency) {
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 2;
  return '${format.format(amount)} $currency';
}
