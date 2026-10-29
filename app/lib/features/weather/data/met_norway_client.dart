import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../integrations/home_assistant/api/dio_error_mapper.dart';
import '../domain/weather.dart';

/// MET Norway Locationforecast 2.0 (https://api.met.no/weatherapi/locationforecast/2.0/documentation).
///
/// Terms (https://api.met.no/doc/TermsOfService): requests must identify the
/// app in the User-Agent, coordinates use at most 4 decimals, data is
/// CC BY 4.0 (attribution shown in the UI) and responses should be cached.
/// We round to 2 decimals (~1 km) for privacy and cache for 30 minutes.
/// Weather for coordinates (MET Norway in production, synthetic in mock mode).
abstract interface class LocationWeatherService {
  Future<WeatherReport> forecast({
    required double latitude,
    required double longitude,
    WeatherSource source = WeatherSource.device,
  });
}

class MetNorwayClient implements LocationWeatherService {
  MetNorwayClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = 'https://api.met.no'
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers = {'User-Agent': userAgent};
  }

  static const userAgent =
      'OpenSmartHome/0.1 github.com/jevrajevremovic-dotcom/open-smart-home';
  final Dio _dio;

  static double roundCoordinate(double v) => (v * 100).roundToDouble() / 100;

  @override
  Future<WeatherReport> forecast({
    required double latitude,
    required double longitude,
    WeatherSource source = WeatherSource.device,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '/weatherapi/locationforecast/2.0/compact',
        queryParameters: {
          'lat': roundCoordinate(latitude),
          'lon': roundCoordinate(longitude),
        },
      );
      return parseMetForecast(
        response.data,
        now: DateTime.now(),
        source: source,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

/// Converts the `compact` response into current conditions and 5 days.
@visibleForTesting
WeatherReport parseMetForecast(
  Object? json, {
  required DateTime now,
  WeatherSource source = WeatherSource.device,
}) {
  final properties = json is Map ? json['properties'] : null;
  final series = properties is Map ? properties['timeseries'] : null;
  if (series is! List || series.isEmpty) {
    throw const AppFailure(
      FailureKind.parsing,
      debugMessage: 'MET response without timeseries',
    );
  }
  final entries = <({DateTime time, Map<String, Object?> data})>[
    for (final e in series)
      if (e is Map &&
          e['time'] is String &&
          e['data'] is Map &&
          DateTime.tryParse(e['time'] as String) != null)
        (
          time: DateTime.parse(e['time'] as String).toLocal(),
          data: (e['data'] as Map).cast<String, Object?>(),
        ),
  ];
  if (entries.isEmpty) {
    throw const AppFailure(
      FailureKind.parsing,
      debugMessage: 'no valid MET entries',
    );
  }

  Map<Object?, Object?>? details(Map<String, Object?> data, String block) {
    final b = data[block];
    return b is Map ? b['details'] as Map<Object?, Object?>? : null;
  }

  String? symbol(Map<String, Object?> data, List<String> blocks) {
    for (final block in blocks) {
      final b = data[block];
      final code = b is Map && b['summary'] is Map
          ? (b['summary'] as Map)['symbol_code']
          : null;
      if (code is String) return code;
    }
    return null;
  }

  double? numOf(Map<Object?, Object?>? m, String key) =>
      m?[key] is num ? (m![key] as num).toDouble() : null;

  final first = entries.first.data;
  final instant = details(first, 'instant');
  final wind = numOf(instant, 'wind_speed');
  final current = WeatherNow(
    condition: WeatherCondition.fromMetSymbol(
      symbol(first, ['next_1_hours', 'next_6_hours', 'next_12_hours']),
    ),
    temperature: numOf(instant, 'air_temperature'),
    humidity: numOf(instant, 'relative_humidity'),
    windSpeed: wind == null
        ? null
        : double.parse((wind * 3.6).toStringAsFixed(1)), // m/s → km/h
    windSpeedUnit: 'km/h',
  );

  final daily = <DailyForecast>[];
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d < 7; d++) {
    final day = DateTime(today.year, today.month, today.day + d);
    final dayEntries = entries
        .where((e) => DateTime(e.time.year, e.time.month, e.time.day) == day)
        .toList();
    if (dayEntries.isEmpty) continue;
    final temps = [
      for (final e in dayEntries)
        ?numOf(details(e.data, 'instant'), 'air_temperature'),
    ];
    var precipitation = 0.0;
    for (var i = 0; i < dayEntries.length; i++) {
      final hourly =
          i + 1 < dayEntries.length &&
          dayEntries[i + 1].time.difference(dayEntries[i].time).inHours == 1;
      precipitation +=
          numOf(
            details(
              dayEntries[i].data,
              hourly ? 'next_1_hours' : 'next_6_hours',
            ),
            'precipitation_amount',
          ) ??
          0;
    }
    // Representative symbol: the entry closest to midday.
    final midday = dayEntries.reduce(
      (a, b) => (a.time.hour - 12).abs() <= (b.time.hour - 12).abs() ? a : b,
    );
    daily.add(
      DailyForecast(
        date: day,
        condition: WeatherCondition.fromMetSymbol(
          symbol(midday.data, [
            'next_6_hours',
            'next_12_hours',
            'next_1_hours',
          ]),
        ),
        high: temps.isEmpty ? null : temps.reduce(max),
        low: temps.isEmpty ? null : temps.reduce(min),
        precipitation: double.parse(precipitation.toStringAsFixed(1)),
      ),
    );
  }
  final fromHour = DateTime(now.year, now.month, now.day, now.hour);
  final hourly = [
    for (final e in entries)
      if (!e.time.isBefore(fromHour) &&
          e.time.isBefore(fromHour.add(const Duration(hours: 24))) &&
          e.data['next_1_hours'] != null)
        HourlyForecast(
          time: e.time,
          condition: WeatherCondition.fromMetSymbol(
            symbol(e.data, ['next_1_hours']),
          ),
          temperature: numOf(details(e.data, 'instant'), 'air_temperature'),
        ),
  ];
  return WeatherReport(
    source: source,
    now: current,
    daily: daily,
    hourly: hourly,
    updatedAt: now,
  );
}
