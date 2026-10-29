import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';

/// The device as the service screen shows it.
@immutable
class DeviceInfo {
  const DeviceInfo({
    this.manufacturer,
    this.model,
    this.android,
    this.sdk,
    this.package,
    this.deviceOwner = false,
  });

  final String? manufacturer;
  final String? model;
  final String? android;
  final int? sdk;
  final String? package;

  /// Installer-provisioned: the kiosk can be locked for real.
  final bool deviceOwner;
}

/// Android device-owner powers for installer-managed wall panels (see
/// DeviceAdmin.kt). Without them every call is a harmless no-op.
abstract interface class DeviceAdminPlatform {
  Future<DeviceInfo> info();

  /// Locks the app on screen (no home, recents, notifications); `false`
  /// when the app is not the device owner.
  Future<bool> lockTask(bool on);

  /// Screen on while powered, the app as home screen.
  Future<bool> applyPolicies();

  /// Gives the device back (owner rights removed).
  Future<bool> release();
}

class AndroidDeviceAdmin implements DeviceAdminPlatform {
  static const _channel = MethodChannel('org.opensmarthome/device');
  static final _log = AppLogger('DeviceAdmin');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      _log.warning('$method failed', e.code);
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<DeviceInfo> info() async {
    final m = await _call<Map<Object?, Object?>>('info');
    if (m == null) return const DeviceInfo();
    return DeviceInfo(
      manufacturer: m['manufacturer'] as String?,
      model: m['model'] as String?,
      android: m['android'] as String?,
      sdk: m['sdk'] as int?,
      package: m['package'] as String?,
      deviceOwner: m['deviceOwner'] == true,
    );
  }

  @override
  Future<bool> lockTask(bool on) async =>
      await _call<bool>('lockTask', {'on': on}) ?? false;

  @override
  Future<bool> applyPolicies() async =>
      await _call<bool>('applyPolicies') ?? false;

  @override
  Future<bool> release() async => await _call<bool>('release') ?? false;
}

final deviceAdminProvider = Provider<DeviceAdminPlatform>(
  (ref) => AndroidDeviceAdmin(),
);

/// Read once per app start (owner rights change only by provisioning).
final deviceInfoProvider = FutureProvider<DeviceInfo>(
  (ref) => ref.watch(deviceAdminProvider).info(),
);
