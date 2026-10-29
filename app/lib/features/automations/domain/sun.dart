import 'dart:math';

/// Sunrise and sunset on [day] at a place, from the sunrise equation
/// (good to a minute or two; no network needed). `null` when the sun does
/// not rise or set that day (polar day or night).
({DateTime sunrise, DateTime sunset})? sunTimes(
  DateTime day,
  double latitude,
  double longitude,
) {
  double rad(double d) => d * pi / 180;
  double deg(double r) => r * 180 / pi;
  final noon = DateTime.utc(day.year, day.month, day.day, 12);
  final julianDate = noon.millisecondsSinceEpoch / 86400000 + 2440587.5;
  final n = (julianDate - 2451545.0 + 0.0008).roundToDouble();
  final meanNoon = n - longitude / 360;
  final m = (357.5291 + 0.98560028 * meanNoon) % 360;
  final c =
      1.9148 * sin(rad(m)) + 0.02 * sin(rad(2 * m)) + 0.0003 * sin(rad(3 * m));
  final lambda = (m + c + 180 + 102.9372) % 360;
  final transit =
      2451545.0 +
      meanNoon +
      0.0053 * sin(rad(m)) -
      0.0069 * sin(rad(2 * lambda));
  final sinDecl = sin(rad(lambda)) * sin(rad(23.4397));
  final cosDecl = cos(asin(sinDecl));
  final cosHour =
      (sin(rad(-0.833)) - sin(rad(latitude)) * sinDecl) /
      (cos(rad(latitude)) * cosDecl);
  if (cosHour < -1 || cosHour > 1) return null;
  final hour = deg(acos(cosHour));
  DateTime at(double julian) => DateTime.fromMillisecondsSinceEpoch(
    ((julian - 2440587.5) * 86400000).round(),
    isUtc: true,
  ).toLocal();
  return (sunrise: at(transit - hour / 360), sunset: at(transit + hour / 360));
}
