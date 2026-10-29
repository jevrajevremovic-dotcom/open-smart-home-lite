import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/storage/app_preferences.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/home_state_repository.dart';
import '../../devices/domain/device_kind.dart';
import '../data/device_location.dart';
import '../data/ha_weather.dart';
import '../data/met_norway_client.dart';
import '../../../core/utils/value_list.dart';
import '../domain/weather.dart';

const _refreshEvery = Duration(minutes: 30);

/// The Home Assistant weather entity to show (`weather.forecast_home` – the
/// default Met.no entity – if present, else the first weather entity).
final homeWeatherEntityIdProvider = Provider<String?>((ref) {
  final ids = ref.watch(
    homeSnapshotProvider.select(
      (s) => ValueList(
        [
          for (final d in s.devices.values)
            if (d.kind == DeviceKind.weather && d.available) d.id,
        ]..sort(),
      ),
    ),
  );
  if (ids.isEmpty) return null;
  return ids.contains('weather.forecast_home')
      ? 'weather.forecast_home'
      : ids.first;
});

/// Daily forecast via the documented `weather.get_forecasts` service.
final homeForecastProvider = FutureProvider<List<DailyForecast>>((ref) async {
  final id = ref.watch(homeWeatherEntityIdProvider);
  final api = ref.watch(homeAssistantApiProvider);
  final live = ref.watch(syncStatusProvider) == SyncStatus.live;
  if (id == null || api == null || !live) return const [];
  final timer = Timer(_refreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final response = await api.callServiceForResponse(
    'weather',
    'get_forecasts',
    data: {'entity_id': id, 'type': 'daily'},
  );
  return parseHaForecast(response, id);
});

/// Hourly forecast. Not every weather integration offers one; then empty.
final homeHourlyForecastProvider = FutureProvider<List<HourlyForecast>>((
  ref,
) async {
  final id = ref.watch(homeWeatherEntityIdProvider);
  final api = ref.watch(homeAssistantApiProvider);
  final live = ref.watch(syncStatusProvider) == SyncStatus.live;
  if (id == null || api == null || !live) return const [];
  final timer = Timer(_refreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  try {
    final response = await api.callServiceForResponse(
      'weather',
      'get_forecasts',
      data: {'entity_id': id, 'type': 'hourly'},
    );
    return parseHaHourlyForecast(response, id, now: DateTime.now());
  } on AppFailure catch (e) {
    if (e.isTransient) rethrow;
    return const []; // entity does not support hourly forecasts
  }
});

/// Off until the user agrees to send the home's approximate location
/// (from Home Assistant, rounded to ~1 km) to MET Norway. Only used when
/// Home Assistant has no weather entity.
class HomeLocationWeatherController extends Notifier<bool> {
  static const _key = 'weather.homeLocation';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final homeLocationWeatherEnabledProvider =
    NotifierProvider<HomeLocationWeatherController, bool>(
      HomeLocationWeatherController.new,
    );

/// MET Norway forecast for the home location; `null` when not enabled,
/// when HA has its own weather entity, or HA has no home coordinates.
final homeLocationWeatherProvider = FutureProvider<WeatherReport?>((ref) async {
  if (!ref.watch(homeLocationWeatherEnabledProvider)) return null;
  if (ref.watch(homeWeatherEntityIdProvider) != null) return null;
  final config = await ref.watch(serverConfigProvider.future);
  final lat = config?.latitude;
  final lon = config?.longitude;
  if (lat == null || lon == null) return null;
  final timer = Timer(_refreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref
      .read(locationWeatherServiceProvider)
      .forecast(
        latitude: lat,
        longitude: lon,
        source: WeatherSource.homeLocation,
      );
});

/// Weather at home: the Home Assistant weather entity (nothing leaves the
/// network) or, if there is none and the user opted in, MET Norway.
final homeWeatherProvider = Provider<WeatherReport?>((ref) {
  final id = ref.watch(homeWeatherEntityIdProvider);
  final device = id == null ? null : ref.watch(deviceProvider(id));
  if (device == null) return ref.watch(homeLocationWeatherProvider).value;
  final daily = ref.watch(homeForecastProvider).value ?? const [];
  final hourly = ref.watch(homeHourlyForecastProvider).value ?? const [];
  return weatherFromEntity(device, daily: daily, hourly: hourly);
});

// ---------------------------------------------------------------------------
// Optional: weather at the device's location (opt-in, mobile only)

final deviceLocatorProvider = Provider<DeviceLocator>((ref) {
  if (ref.watch(appConfigProvider).mockMode) return _MockLocator();
  return GeolocatorDeviceLocator();
});

final locationWeatherServiceProvider = Provider<LocationWeatherService>((ref) {
  if (ref.watch(appConfigProvider).mockMode) return _MockLocationWeather();
  return MetNorwayClient();
});

/// Off until the user enables it after reading what is sent where.
class DeviceWeatherEnabledController extends Notifier<bool> {
  static const _key = 'weather.deviceLocation';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
  }
}

final deviceWeatherEnabledProvider =
    NotifierProvider<DeviceWeatherEnabledController, bool>(
      DeviceWeatherEnabledController.new,
    );

sealed class DeviceWeatherState {
  const DeviceWeatherState();
}

final class DeviceWeatherReady extends DeviceWeatherState {
  const DeviceWeatherReady(this.report, {this.kmFromHome});
  final WeatherReport report;

  /// Distance to Home Assistant's home location, when both are known.
  final double? kmFromHome;

  /// Within this distance the device is "at home" and its own forecast
  /// would only duplicate the home card.
  static const atHomeKm = 10.0;

  bool get atHome => kmFromHome != null && kmFromHome! < atHomeKm;
}

final class DeviceWeatherNoLocation extends DeviceWeatherState {
  const DeviceWeatherNoLocation(this.reason);
  final LocationResult reason;
}

/// `null` = disabled or unsupported on this platform.
final deviceWeatherProvider = FutureProvider<DeviceWeatherState?>((ref) async {
  final locator = ref.watch(deviceLocatorProvider);
  if (!ref.watch(deviceWeatherEnabledProvider) || !locator.isSupported) {
    return null;
  }
  final timer = Timer(_refreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final location = await locator.approximateLocation();
  if (location is! LocationFound) return DeviceWeatherNoLocation(location);
  final report = await ref
      .read(locationWeatherServiceProvider)
      .forecast(latitude: location.latitude, longitude: location.longitude);
  final config = ref.read(serverConfigProvider).value;
  final km = config?.latitude == null || config?.longitude == null
      ? null
      : distanceKm(
          location.latitude,
          location.longitude,
          config!.latitude!,
          config.longitude!,
        );
  return DeviceWeatherReady(report, kmFromHome: km);
});

class _MockLocator implements DeviceLocator {
  @override
  bool get isSupported => true;

  @override
  Future<LocationResult> approximateLocation() async =>
      const LocationFound(44.82, 20.46);

  @override
  Future<void> openSettings() async {}
}

class _MockLocationWeather implements LocationWeatherService {
  @override
  Future<WeatherReport> forecast({
    required double latitude,
    required double longitude,
    WeatherSource source = WeatherSource.device,
  }) async {
    final today = DateTime.now();
    return WeatherReport(
      source: source,
      updatedAt: today,
      now: const WeatherNow(
        condition: WeatherCondition.clearDay,
        temperature: 21.3,
        humidity: 48,
        windSpeed: 7.2,
        windSpeedUnit: 'km/h',
      ),
      daily: [
        for (var i = 0; i < 7; i++)
          DailyForecast(
            date: DateTime(today.year, today.month, today.day + i),
            condition: i == 3
                ? WeatherCondition.rain
                : WeatherCondition.partlyCloudy,
            high: 22.0 - i,
            low: 11.0 - i / 2,
          ),
      ],
    );
  }
}
