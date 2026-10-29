import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/app_preferences.dart';
import '../data/device_location.dart';
import '../data/met_norway_client.dart';
import '../domain/weather.dart';

const _refreshEvery = Duration(minutes: 30);

/// The home's approximate location, saved on this phone when the user
/// turns the home forecast on (where the phone was then, rounded to
/// ~1 km). `null` until then.
typedef HomeLocation = ({double latitude, double longitude});

/// Off until the user agrees to send the home's approximate location to
/// MET Norway.
class HomeLocationWeatherController extends Notifier<HomeLocation?> {
  static const _key = 'weather.homeLocation';

  @override
  HomeLocation? build() {
    final json = ref.watch(appPreferencesProvider).readJson(_key);
    final lat = json?['latitude'];
    final lon = json?['longitude'];
    return lat is num && lon is num
        ? (latitude: lat.toDouble(), longitude: lon.toDouble())
        : null;
  }

  Future<void> set(HomeLocation? location) async {
    state = location == null
        ? null
        : (
            latitude: MetNorwayClient.roundCoordinate(location.latitude),
            longitude: MetNorwayClient.roundCoordinate(location.longitude),
          );
    final saved = state;
    await ref
        .read(appPreferencesProvider)
        .writeJson(
          _key,
          saved == null
              ? null
              : {'latitude': saved.latitude, 'longitude': saved.longitude},
        );
  }
}

final homeLocationWeatherEnabledProvider =
    NotifierProvider<HomeLocationWeatherController, HomeLocation?>(
      HomeLocationWeatherController.new,
    );

/// MET Norway forecast for the home location; `null` when not enabled.
final homeLocationWeatherProvider = FutureProvider<WeatherReport?>((ref) async {
  final home = ref.watch(homeLocationWeatherEnabledProvider);
  if (home == null) return null;
  final timer = Timer(_refreshEvery, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref
      .read(locationWeatherServiceProvider)
      .forecast(
        latitude: home.latitude,
        longitude: home.longitude,
        source: WeatherSource.homeLocation,
      );
});

/// Weather at home, if the user turned it on.
final homeWeatherProvider = Provider<WeatherReport?>(
  (ref) => ref.watch(homeLocationWeatherProvider).value,
);

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

  /// Distance to the saved home location, when both are known.
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
  final home = ref.read(homeLocationWeatherEnabledProvider);
  final km = home == null
      ? null
      : distanceKm(
          location.latitude,
          location.longitude,
          home.latitude,
          home.longitude,
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
