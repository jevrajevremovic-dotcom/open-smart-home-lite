import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/logging/app_logger.dart';

sealed class LocationResult {
  const LocationResult();
}

final class LocationFound extends LocationResult {
  const LocationFound(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

final class LocationDenied extends LocationResult {
  const LocationDenied({required this.permanently});

  /// Only the system settings can grant it now.
  final bool permanently;
}

final class LocationServicesOff extends LocationResult {
  const LocationServicesOff();
}

final class LocationUnavailable extends LocationResult {
  const LocationUnavailable();
}

/// Approximate device location (never precise GPS: weather does not need it).
abstract interface class DeviceLocator {
  bool get isSupported;
  Future<LocationResult> approximateLocation();
  Future<void> openSettings();
}

class GeolocatorDeviceLocator implements DeviceLocator {
  static final _log = AppLogger('Location');

  /// Mobile only: browsers need HTTPS for geolocation and cannot send the
  /// User-Agent MET Norway requires.
  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<LocationResult> approximateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServicesOff();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationDenied(permanently: true);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationDenied(permanently: false);
      }
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            ),
          );
      return LocationFound(position.latitude, position.longitude);
    } on Object catch (e) {
      _log.warning('Location unavailable', e.runtimeType);
      return const LocationUnavailable();
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
