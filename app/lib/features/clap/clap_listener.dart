import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/logging/app_logger.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/capability.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_actions.dart';
import '../devices/presentation/device_presentation.dart';
import '../kiosk/application/kiosk_controller.dart';
import 'clap_detector.dart';
import 'clap_platform.dart';

/// Any real device can be chosen; what a clap does depends on its kind
/// (see [clapCommandFor]).
bool isClapTarget(SmartHomeDevice d) =>
    !d.isAuxiliary && d.kind != DeviceKind.unknown;

/// The command a double clap sends to [d], or `null` when the device has no
/// simple action (a sensor, a camera, an alarm panel needing a mode or a
/// code): then the clap opens its screen instead.
///
/// Unlocking, opening a garage door and disarming are critical commands:
/// they still ask for confirmation on the screen, as when tapped.
DeviceCommand? clapCommandFor(SmartHomeDevice d) {
  final s = d.state;
  bool can(Capability c) => d.supports(c);
  if (d.kind.isRoutine || d.kind == DeviceKind.button) {
    return can(Capability.trigger) ? const Activate() : null;
  }
  if (d.kind == DeviceKind.lock) {
    return switch (s.lockState) {
      DoorLockState.locked when can(Capability.unlock) => const UnlockDevice(),
      DoorLockState.unlocked ||
      DoorLockState.open when can(Capability.lock) => const LockDevice(),
      _ => null,
    };
  }
  if (can(Capability.open) && can(Capability.close)) {
    final closed =
        s.coverState == CoverState.closed ||
        s.coverState == CoverState.closing ||
        s.position == 0;
    return closed ? const OpenCover() : const CloseCover();
  }
  if (d.kind == DeviceKind.vacuum) {
    return s.raw == 'cleaning'
        ? (can(Capability.vacuumReturnHome) ? const VacuumReturnHome() : null)
        : (can(Capability.vacuumStart) ? const VacuumStart() : null);
  }
  if (can(Capability.mediaPlay) || can(Capability.mediaPause)) {
    return const MediaPlayPause();
  }
  if (can(Capability.power)) {
    return s.isOn == true ? const TurnOff() : const TurnOn();
  }
  return null;
}

/// Listens for a double clap while the kiosk dashboard is on screen (and
/// nothing covers it, so Assist can use the microphone) and runs the
/// chosen action.
class KioskClapListener extends ConsumerStatefulWidget {
  const KioskClapListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskClapListener> createState() => _KioskClapListenerState();
}

class _KioskClapListenerState extends ConsumerState<KioskClapListener> {
  static final _log = AppLogger('Clap');

  StreamSubscription<double>? _sub;
  ClapDetector? _detector;
  bool _foreground = true;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: () => _setForeground(true),
    onHide: () => _setForeground(false),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start observing
  }

  void _setForeground(bool v) {
    if (_foreground == v) return;
    setState(() => _foreground = v);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _sync({required bool active, required ClapSensitivity sensitivity}) {
    if (!active) {
      if (_sub != null) {
        unawaited(_sub!.cancel());
        _sub = null;
      }
      return;
    }
    if (_sub != null && _detector?.sensitivity == sensitivity) return;
    unawaited(_sub?.cancel());
    final detector = _detector = ClapDetector(sensitivity: sensitivity);
    _sub = ref
        .read(clapPlatformProvider)
        .levels()
        .listen(
          (level) {
            if (detector.add(level)) unawaited(_run());
          },
          onError: (Object e) {
            // E.g. permission withdrawn in system settings.
            _log.warning('microphone unavailable', e.runtimeType);
            _sub = null;
          },
          cancelOnError: true,
        );
  }

  Future<void> _run() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final id = ref.read(kioskSettingsProvider).clapTargetId;
    final device = id == null ? null : ref.read(deviceProvider(id));
    if (device == null || !isClapTarget(device)) return;
    final command = clapCommandFor(device);
    if (command == null) {
      // Nothing simple to switch: show the device instead.
      unawaited(context.push(AppRoutes.device(device.id, kiosk: true)));
      return;
    }
    // Same path as a tap: critical commands ask for confirmation first.
    if (!await runDeviceCommand(context, ref, device, command)) return;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            command is Activate
                ? l10n.sceneActivated(device.name)
                : command is TurnOn || command is TurnOff
                ? l10n.clapSwitched(
                    device.name,
                    command is TurnOn ? l10n.stateOn : l10n.stateOff,
                  )
                : l10n.clapDone(device.name),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final platform = ref.watch(clapPlatformProvider);
    // A dialog, sheet or detail screen on top pauses listening.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    final active =
        platform.supported &&
        settings.clapEnabled &&
        settings.clapTargetId != null &&
        ref.watch(kioskActiveProvider) &&
        _foreground &&
        onTop;
    _sync(active: active, sensitivity: settings.clapSensitivity);
    return widget.child;
  }
}

/// Short description of what a clap does to [d], for settings.
String clapTargetLabel(AppLocalizations l10n, SmartHomeDevice? d) {
  if (d == null) return l10n.clapTargetNone;
  final action = switch (d) {
    _ when d.kind.isRoutine || d.kind == DeviceKind.button => l10n.svc_activate,
    _ when d.kind == DeviceKind.lock => l10n.clapLockAction,
    _ when d.kind == DeviceKind.garageDoor => l10n.clapGarageAction,
    _ when d.supports(Capability.open) && d.supports(Capability.close) =>
      l10n.clapCoverAction,
    _ when d.kind == DeviceKind.vacuum => l10n.clapVacuumAction,
    _
        when d.supports(Capability.mediaPlay) ||
            d.supports(Capability.mediaPause) =>
      l10n.clapMediaAction,
    _ when d.supports(Capability.power) => l10n.clapToggle,
    _ => l10n.clapOpenScreen,
  };
  return '${d.name} · $action';
}

IconData clapTargetIcon(SmartHomeDevice? d) =>
    d == null ? Icons.touch_app_outlined : DevicePresentation.icon(d);
