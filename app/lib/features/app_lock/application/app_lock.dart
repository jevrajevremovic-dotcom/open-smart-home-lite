import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../data/device_auth.dart';

final deviceAuthProvider = Provider<DeviceAuth>((ref) => LocalDeviceAuth());

final deviceAuthAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceAuthProvider).isAvailable(),
);

@immutable
class AppLockSettings {
  const AppLockSettings({
    this.lockApp = false,
    this.confirmCritical = false,
    this.lockAfter = const Duration(minutes: 1),
  });

  factory AppLockSettings.fromJson(Map<String, Object?>? json) =>
      AppLockSettings(
        lockApp: json?['lockApp'] == true,
        confirmCritical: json?['confirmCritical'] == true,
        lockAfter: Duration(
          seconds: json?['lockAfterSeconds'] is int
              ? json!['lockAfterSeconds']! as int
              : 60,
        ),
      );

  /// Ask for fingerprint/face/PIN when opening the app.
  final bool lockApp;

  /// Also before unlocking doors, disarming alarms, opening garages.
  final bool confirmCritical;

  /// Time in the background after which the app locks again.
  final Duration lockAfter;

  Map<String, Object?> toJson() => {
    'lockApp': lockApp,
    'confirmCritical': confirmCritical,
    'lockAfterSeconds': lockAfter.inSeconds,
  };

  AppLockSettings copyWith({bool? lockApp, bool? confirmCritical}) =>
      AppLockSettings(
        lockApp: lockApp ?? this.lockApp,
        confirmCritical: confirmCritical ?? this.confirmCritical,
        lockAfter: lockAfter,
      );
}

class AppLockSettingsController extends Notifier<AppLockSettings> {
  static const _key = 'security.appLock';

  @override
  AppLockSettings build() => AppLockSettings.fromJson(
    ref.watch(appPreferencesProvider).readJson(_key),
  );

  Future<void> update(AppLockSettings Function(AppLockSettings) change) async {
    state = change(state);
    await ref.read(appPreferencesProvider).writeJson(_key, state.toJson());
  }
}

final appLockSettingsProvider =
    NotifierProvider<AppLockSettingsController, AppLockSettings>(
      AppLockSettingsController.new,
    );

/// Whether the lock screen is shown right now. Locked at start when the
/// lock is on; locks again after [AppLockSettings.lockAfter] in the
/// background.
class AppLockController extends Notifier<bool> {
  DateTime? _backgroundSince;

  @override
  bool build() => ref.read(appLockSettingsProvider).lockApp;

  void onBackground() => _backgroundSince = DateTime.now();

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    final settings = ref.read(appLockSettingsProvider);
    if (!settings.lockApp || since == null) return;
    if (DateTime.now().difference(since) >= settings.lockAfter) state = true;
  }

  /// Locks immediately (when the lock is on).
  void lockNow() {
    if (ref.read(appLockSettingsProvider).lockApp) state = true;
  }

  Future<bool> unlock(String reason) async {
    final ok = await ref.read(deviceAuthProvider).authenticate(reason);
    if (ok) state = false;
    return ok;
  }

  /// Turning the lock off unlocks immediately.
  void settingsChanged(AppLockSettings s) {
    if (!s.lockApp) state = false;
  }
}

final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);
