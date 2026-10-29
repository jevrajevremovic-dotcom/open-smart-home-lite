import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../devices/application/device_providers.dart';
import '../application/kiosk_controller.dart';
import '../data/approach_platform.dart';
import '../data/kiosk_settings.dart';

/// Wakes the idle kiosk screen when someone comes near: when the chosen
/// motion sensor in Home Assistant turns on, or when the front camera sees
/// movement. Only while the screen is idle — the camera is off otherwise.
class KioskApproachWaker extends ConsumerStatefulWidget {
  const KioskApproachWaker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskApproachWaker> createState() => _KioskApproachWakerState();
}

class _KioskApproachWakerState extends ConsumerState<KioskApproachWaker> {
  static final _log = AppLogger('Approach');

  StreamSubscription<void>? _camera;
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
    unawaited(_camera?.cancel());
    super.dispose();
  }

  void _wake() {
    if (!mounted || !ref.read(kioskDimmedProvider)) return;
    ref.read(kioskDimmedProvider.notifier).set(false);
  }

  void _syncCamera(bool active) {
    if (!active) {
      unawaited(_camera?.cancel());
      _camera = null;
      return;
    }
    if (_camera != null) return;
    _camera = ref
        .read(approachPlatformProvider)
        .motion()
        .listen(
          (_) => _wake(),
          onError: (Object e) {
            // E.g. permission withdrawn or the camera used elsewhere.
            _log.warning('camera unavailable', e.runtimeType);
            _camera = null;
          },
          cancelOnError: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(kioskSettingsProvider);
    final idle =
        ref.watch(kioskDimmedProvider) &&
        ref.watch(kioskActiveProvider) &&
        _foreground;
    _syncCamera(
      idle &&
          settings.approachWake == ApproachWake.camera &&
          ref.watch(approachPlatformProvider).supported,
    );
    final sensor = settings.approachSensorId;
    if (settings.approachWake == ApproachWake.sensor && sensor != null) {
      ref.listen(deviceProvider(sensor).select((d) => d?.state.isActive), (
        before,
        now,
      ) {
        if (now == true && before != true) _wake();
      });
    }
    return widget.child;
  }
}
