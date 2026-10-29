import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/app_preferences.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';

/// Child / guest mode for this device: hides sensitive devices and locks
/// settings and adding devices behind a PIN. Local only – Home Assistant
/// permissions are unchanged (use a separate HA user for real limits).
@immutable
class RestrictedSettings {
  const RestrictedSettings({
    this.enabled = false,
    this.hideSecurity = true,
    this.hideCameras = true,
    this.pinHash,
    this.pinSalt,
  });

  factory RestrictedSettings.fromJson(Map<String, Object?>? j) =>
      RestrictedSettings(
        enabled: j?['enabled'] == true && j?['pinHash'] is String,
        hideSecurity: j?['hideSecurity'] != false,
        hideCameras: j?['hideCameras'] != false,
        pinHash: j?['pinHash'] as String?,
        pinSalt: j?['pinSalt'] as String?,
      );

  final bool enabled;

  /// Locks, alarm panels, garage doors, sirens.
  final bool hideSecurity;
  final bool hideCameras;
  final String? pinHash;
  final String? pinSalt;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'hideSecurity': hideSecurity,
    'hideCameras': hideCameras,
    'pinHash': pinHash,
    'pinSalt': pinSalt,
  };

  RestrictedSettings copyWith({
    bool? enabled,
    bool? hideSecurity,
    bool? hideCameras,
    String? pinHash,
    String? pinSalt,
  }) => RestrictedSettings(
    enabled: enabled ?? this.enabled,
    hideSecurity: hideSecurity ?? this.hideSecurity,
    hideCameras: hideCameras ?? this.hideCameras,
    pinHash: pinHash ?? this.pinHash,
    pinSalt: pinSalt ?? this.pinSalt,
  );

  Set<DeviceKind> get hiddenKinds => !enabled
      ? const {}
      : {
          if (hideSecurity) ...{
            DeviceKind.lock,
            DeviceKind.alarm,
            DeviceKind.garageDoor,
            DeviceKind.siren,
          },
          if (hideCameras) ...{DeviceKind.camera, DeviceKind.doorbell},
        };

  bool hides(SmartHomeDevice d) => hiddenKinds.contains(d.kind);
}

class RestrictedController extends Notifier<RestrictedSettings> {
  static const _key = 'restricted.settings';

  @override
  RestrictedSettings build() => RestrictedSettings.fromJson(
    ref.watch(appPreferencesProvider).readJson(_key),
  );

  Future<void> _save(RestrictedSettings s) async {
    state = s;
    await ref.read(appPreferencesProvider).writeJson(_key, s.toJson());
  }

  Future<void> setOptions({bool? hideSecurity, bool? hideCameras}) => _save(
    state.copyWith(hideSecurity: hideSecurity, hideCameras: hideCameras),
  );

  /// Turns the mode on with a new PIN (stored only as a PBKDF2 hash).
  Future<void> enable(String pin) {
    final salt = PinHasher.newSalt();
    return _save(
      state.copyWith(
        enabled: true,
        pinSalt: salt,
        pinHash: PinHasher.hash(pin, salt),
      ),
    );
  }

  /// `true` and off when [pin] matches.
  Future<bool> disable(String pin) async {
    final hash = state.pinHash;
    final salt = state.pinSalt;
    if (hash == null || salt == null || !PinHasher.verify(pin, salt, hash)) {
      return false;
    }
    await _save(
      RestrictedSettings(
        hideSecurity: state.hideSecurity,
        hideCameras: state.hideCameras,
      ),
    );
    return true;
  }
}

final restrictedModeProvider =
    NotifierProvider<RestrictedController, RestrictedSettings>(
      RestrictedController.new,
    );
