import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/app_preferences.dart';
import '../../authentication/application/session_controller.dart';
import '../data/kiosk_settings.dart';
import 'kiosk_people.dart';

class KioskSettingsController extends Notifier<KioskSettings> {
  @override
  KioskSettings build() => KioskSettings.fromJson(
    ref.watch(appPreferencesProvider).kioskSettingsJson,
  );

  Future<void> update(KioskSettings Function(KioskSettings) change) async {
    state = change(state);
    await ref.read(appPreferencesProvider).setKioskSettingsJson(state.toJson());
  }

  /// Returns `false` when [pin] is not 4–8 digits.
  Future<bool> setPin(String pin) async {
    if (!PinHasher.validPin.hasMatch(pin)) return false;
    final salt = PinHasher.newSalt();
    // ~tens of ms once per PIN change; not worth an isolate.
    final hash = PinHasher.hash(pin, salt);
    await update((s) => s.copyWith(pinHash: hash, pinSalt: salt));
    return true;
  }

  Future<void> removePin() => update((s) => s.copyWith(clearPin: true));
}

final kioskSettingsProvider =
    NotifierProvider<KioskSettingsController, KioskSettings>(
      KioskSettingsController.new,
    );

/// Result of an exit attempt.
enum PinCheck { accepted, wrong, lockedOut }

/// Whether kiosk mode is active. While it is, the router keeps the user on
/// kiosk routes; leaving requires the PIN (if one is set).
class KioskSessionController extends Notifier<bool> {
  static final _log = AppLogger('Kiosk');

  static const maxAttempts = 5;
  static const lockout = Duration(seconds: 30);

  int _failures = 0;
  DateTime? _lockedUntil;

  /// Injectable clock for tests.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  @override
  bool build() {
    // Signing out (or wiping data) always leaves kiosk mode.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (previous?.value != null && next.value == null) state = false;
    });
    return ref.read(kioskSettingsProvider).startInKiosk;
  }

  void enter() {
    _log.info('Entering kiosk mode');
    state = true;
  }

  Duration? get remainingLockout {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(now());
    return left.isNegative ? null : left;
  }

  /// Leaves kiosk mode when [pin] matches (or no PIN is configured).
  /// Checks the PIN and leaves kiosk mode when it matches.
  Future<PinCheck> tryExit(String pin) => _check(pin, exit: true);

  /// Checks the PIN (with the same lockout), e.g. before editing the
  /// layout, without leaving kiosk mode.
  Future<PinCheck> verifyPin(String pin) => _check(pin, exit: false);

  /// Before a critical action: the panel's PIN or a member's own PIN
  /// (same lockout). Also returns whose PIN it was, if a member's.
  Future<(PinCheck, String?)> verifyCriticalPin(String pin) async {
    if (remainingLockout != null) return (PinCheck.lockedOut, null);
    final person = ref.read(kioskPeopleProvider.notifier).personWithPin(pin);
    if (person != null) {
      _failures = 0;
      _lockedUntil = null;
      return (PinCheck.accepted, person);
    }
    // Only the panel's own PIN from here (none set: only members' PINs).
    if (!ref.read(kioskSettingsProvider).hasPin) return (_fail(), null);
    return (await _check(pin, exit: false), null);
  }

  Future<PinCheck> _check(String pin, {required bool exit}) async {
    if (remainingLockout != null) return PinCheck.lockedOut;
    final settings = ref.read(kioskSettingsProvider);
    final ok =
        !settings.hasPin ||
        PinHasher.verify(pin, settings.pinSalt!, settings.pinHash!);
    if (ok) {
      _failures = 0;
      _lockedUntil = null;
      if (exit) {
        state = false;
        _log.info('Left kiosk mode');
      }
      return PinCheck.accepted;
    }
    return _fail();
  }

  PinCheck _fail() {
    _failures++;
    _log.warning('Wrong kiosk PIN ($_failures/$maxAttempts)');
    if (_failures >= maxAttempts) {
      _failures = 0;
      _lockedUntil = now().add(lockout);
      return PinCheck.lockedOut;
    }
    return PinCheck.wrong;
  }

  /// Leaves kiosk mode without a PIN — only for sign-out / data wipe.
  void forceExit() => state = false;
}

final kioskActiveProvider = NotifierProvider<KioskSessionController, bool>(
  KioskSessionController.new,
);

/// `true` while the kiosk screensaver covers the screen; cameras stop
/// refreshing then.
final kioskDimmedProvider = NotifierProvider<KioskDimmedController, bool>(
  KioskDimmedController.new,
);

class KioskDimmedController extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool dimmed) => state = dimmed;
}

/// Platform side effects of kiosk mode, behind an interface so widget tests
/// do not touch platform channels.
abstract interface class KioskPlatform {
  Future<void> enterFullscreen();
  Future<void> exitFullscreen();
  Future<void> keepScreenOn(bool on);

  /// Screen brightness for this app's window, 0…1; `null` = the system's.
  Future<void> setBrightness(double? level);
}

class DefaultKioskPlatform implements KioskPlatform {
  static final _log = AppLogger('KioskPlatform');

  @override
  Future<void> enterFullscreen() => _safe(
    'fullscreen',
    () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
  );

  @override
  Future<void> exitFullscreen() => _safe(
    'fullscreen',
    () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
  );

  @override
  Future<void> keepScreenOn(bool on) =>
      _safe('wakelock', () => WakelockPlus.toggle(enable: on));

  static const _brightness = MethodChannel('org.opensmarthome/brightness');

  @override
  Future<void> setBrightness(double? level) => _safe(
    'brightness',
    () => _brightness.invokeMethod<void>('set', {'level': level ?? -1.0}),
  );

  // Unsupported platforms (e.g. web on plain HTTP has no Wake Lock API)
  // must not break kiosk mode.
  Future<void> _safe(String what, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _log.warning('$what not available on this platform', e.runtimeType);
    }
  }
}

final kioskPlatformProvider = Provider<KioskPlatform>(
  (ref) => DefaultKioskPlatform(),
);
