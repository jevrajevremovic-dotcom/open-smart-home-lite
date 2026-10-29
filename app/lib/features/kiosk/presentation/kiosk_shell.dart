import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../assist/presentation/wake_word_listener.dart';
import '../application/device_admin.dart';
import '../../extras/celebrations.dart';
import '../application/kiosk_controller.dart';
import 'camera_popup.dart';
import '../../timers/kiosk_timers.dart';
import 'kiosk_alert_overlay.dart';
import 'kiosk_ambient.dart';
import 'kiosk_greeter.dart';
import 'kiosk_approach_waker.dart';

/// Wraps every kiosk route: fullscreen, screen kept on, back button
/// blocked, return to the kiosk dashboard and dimming after inactivity.
class KioskShell extends ConsumerStatefulWidget {
  const KioskShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<KioskShell> createState() => _KioskShellState();
}

class _KioskShellState extends ConsumerState<KioskShell> {
  Timer? _returnTimer;
  Timer? _dimTimer;
  Timer? _clock;
  double? _brightness;
  bool _brightnessSet = false;
  bool _dimmed = false;
  late final KioskPlatform _platform = ref.read(kioskPlatformProvider);
  late final DeviceAdminPlatform _admin = ref.read(deviceAdminProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_platform.enterFullscreen());
    // Installer-provisioned panels: the kiosk cannot be left at all.
    unawaited(_admin.lockTask(true));
    unawaited(
      _platform.keepScreenOn(ref.read(kioskSettingsProvider).keepScreenOn),
    );
    _restartTimers();
    // Night starts and ends while nobody touches the panel.
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyBrightness(),
    );
    _applyBrightness();
  }

  void _applyBrightness() {
    final level = ref
        .read(kioskSettingsProvider)
        .brightnessAt(DateTime.now(), dimmed: _dimmed);
    if (_brightnessSet && level == _brightness) return;
    _brightnessSet = true;
    _brightness = level;
    unawaited(_platform.setBrightness(level));
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_brightness != null) unawaited(_platform.setBrightness(null));
    _returnTimer?.cancel();
    _dimTimer?.cancel();
    unawaited(_platform.exitFullscreen());
    unawaited(_admin.lockTask(false));
    unawaited(_platform.keepScreenOn(false));
    super.dispose();
  }

  @override
  void didUpdateWidget(KioskShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _restartTimers();
  }

  void _setDimmed(bool dimmed) {
    setState(() => _dimmed = dimmed);
    ref.read(kioskDimmedProvider.notifier).set(dimmed);
    _applyBrightness();
  }

  void _onInteraction() {
    if (_dimmed) _setDimmed(false);
    _restartTimers();
  }

  void _restartTimers() {
    final settings = ref.read(kioskSettingsProvider);
    _returnTimer?.cancel();
    _dimTimer?.cancel();
    if (settings.returnHomeAfter > Duration.zero &&
        widget.location != AppRoutes.kiosk) {
      _returnTimer = Timer(settings.returnHomeAfter, () {
        if (mounted) context.go(AppRoutes.kiosk);
      });
    }
    if (settings.dimAfter > Duration.zero) {
      _dimTimer = Timer(settings.dimAfter, () {
        if (mounted) _setDimmed(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Woken without a touch (the wake word).
    ref.listen(kioskDimmedProvider, (_, dimmed) {
      if (!dimmed && _dimmed) _onInteraction();
    });
    ref.listen(kioskSettingsProvider, (_, next) {
      unawaited(_platform.keepScreenOn(next.keepScreenOn));
      _restartTimers();
      _applyBrightness();
    });
    return PopScope(
      // Android back may only navigate within kiosk, never out of it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.location != AppRoutes.kiosk) {
          context.go(AppRoutes.kiosk);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        // While idle, the idle screen decides what a tap does (it may be
        // the night light rather than waking up).
        onPointerDown: (_) => _dimmed ? null : _onInteraction(),
        child: KioskCameraPopup(
          onShow: _onInteraction,
          child: KioskAlertOverlay(
            child: KioskGreeter(
              child: KioskTimersLayer(
                child: KioskApproachWaker(
                  child: KioskWakeWordListener(
                    child: Stack(
                      children: [
                        widget.child,
                        // Snow in December, confetti on a birthday…
                        const Positioned.fill(child: CelebrationLayer()),
                        // The idle screen fades in slowly (the clock rises
                        // a little); waking is immediate.
                        if (_dimmed)
                          Positioned.fill(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOut,
                              builder: (_, t, child) => Opacity(
                                opacity: t,
                                child: Transform.scale(
                                  scale: 0.98 + 0.02 * t,
                                  child: child,
                                ),
                              ),
                              child: KioskAmbient(onWake: _onInteraction),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Time and date, refreshed at each minute boundary.
class KioskClock extends StatefulWidget {
  const KioskClock({super.key, this.large = false, this.color});

  final bool large;
  final Color? color;

  @override
  State<KioskClock> createState() => _KioskClockState();
}

class _KioskClockState extends State<KioskClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.onSurface;
    return Semantics(
      liveRegion: false,
      child: Column(
        crossAxisAlignment: widget.large
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat.Hm(locale).format(_now),
            style:
                (widget.large
                        ? theme.textTheme.displayLarge
                        : theme.textTheme.displaySmall)
                    ?.copyWith(color: color, fontWeight: FontWeight.w300),
          ),
          Text(
            DateFormat.MMMMEEEEd(locale).format(_now),
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
