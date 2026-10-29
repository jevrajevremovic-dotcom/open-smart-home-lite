import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Weather conditions, shared by Home Assistant and MET Norway.
enum WeatherCondition {
  clearDay,
  clearNight,
  partlyCloudy,
  cloudy,
  fog,
  rain,
  heavyRain,
  snow,
  sleet,
  hail,
  thunderstorm,
  windy,
  exceptional,
  unknown;

  /// Home Assistant weather `condition` values (entity state).
  static WeatherCondition fromHomeAssistant(String? value) => switch (value) {
    'sunny' => clearDay,
    'clear-night' => clearNight,
    'partlycloudy' => partlyCloudy,
    'cloudy' => cloudy,
    'fog' => fog,
    'rainy' => rain,
    'pouring' => heavyRain,
    'snowy' => snow,
    'snowy-rainy' => sleet,
    'hail' => hail,
    'lightning' || 'lightning-rainy' => thunderstorm,
    'windy' || 'windy-variant' => windy,
    'exceptional' => exceptional,
    _ => unknown,
  };

  /// MET Norway `symbol_code`, e.g. `partlycloudy_day`, `heavyrainandthunder`.
  static WeatherCondition fromMetSymbol(String? code) {
    if (code == null) return unknown;
    final base = code.split('_').first;
    if (base.contains('thunder')) return thunderstorm;
    return switch (base) {
      'clearsky' || 'fair' =>
        code.endsWith('_night')
            ? clearNight
            : (base == 'fair' ? partlyCloudy : clearDay),
      'partlycloudy' => partlyCloudy,
      'cloudy' => cloudy,
      'fog' => fog,
      'heavyrain' || 'heavyrainshowers' => heavyRain,
      final b when b.contains('sleet') => sleet,
      final b when b.contains('snow') => snow,
      final b when b.contains('rain') => rain,
      _ => unknown,
    };
  }
}

@immutable
class WeatherNow {
  const WeatherNow({
    required this.condition,
    this.temperature,
    this.temperatureUnit = '°C',
    this.humidity,
    this.windSpeed,
    this.windSpeedUnit,
  });

  final WeatherCondition condition;
  final double? temperature;
  final String temperatureUnit;
  final double? humidity;
  final double? windSpeed;
  final String? windSpeedUnit;
}

@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.condition,
    this.high,
    this.low,
    this.precipitation,
  });

  final DateTime date;
  final WeatherCondition condition;
  final double? high;
  final double? low;

  /// Millimetres.
  final double? precipitation;
}

/// One hour of an hourly forecast.
@immutable
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.condition,
    this.temperature,
    this.precipitationProbability,
  });

  final DateTime time;
  final WeatherCondition condition;
  final double? temperature;

  /// 0–100 %.
  final double? precipitationProbability;
}

enum WeatherSource {
  /// Home Assistant weather entity.
  home,

  /// MET Norway for Home Assistant's home location (opt-in fallback).
  homeLocation,

  /// MET Norway for the phone's location (opt-in).
  device,
}

@immutable
class WeatherReport {
  const WeatherReport({
    required this.source,
    required this.now,
    this.daily = const [],
    this.hourly = const [],
    this.title,
    this.updatedAt,
  });

  final WeatherSource source;
  final WeatherNow now;
  final List<DailyForecast> daily;
  final List<HourlyForecast> hourly;

  /// Home Assistant entity name; `null` for the device location.
  final String? title;
  final DateTime? updatedAt;
}

/// Great-circle distance in kilometres (haversine).
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
