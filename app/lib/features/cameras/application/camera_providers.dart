import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/value_list.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';

/// Camera entities, sorted by name.
final cameraIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final cameras =
      devices.values.where((d) => d.kind == DeviceKind.camera).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final c in cameras) c.id]);
});

/// The latest snapshot of a camera. A failed refresh keeps the previous
/// picture and only marks the feed as [failing].
@immutable
class CameraFrame {
  const CameraFrame({this.bytes, this.takenAt, this.failing = false});

  final Uint8List? bytes;
  final DateTime? takenAt;
  final bool failing;
}

/// How often a visible camera is refreshed, and the pause after a failure.
const cameraRefreshInterval = Duration(seconds: 2);
const _retryAfterFailure = Duration(seconds: 6);

/// Polls `GET /api/camera_proxy/<entity_id>` (documented REST API) while a
/// widget shows the camera. Auto-dispose: when no screen shows it, polling
/// stops – nothing is fetched in the background and nothing is stored.
final cameraFeedProvider = NotifierProvider.autoDispose
    .family<CameraFeed, CameraFrame, String>(CameraFeed.new);

class CameraFeed extends Notifier<CameraFrame> {
  CameraFeed(this.entityId);

  final String entityId;
  static final _log = AppLogger('Camera');

  Timer? _timer;
  bool _disposed = false;

  @override
  CameraFrame build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    scheduleMicrotask(_tick);
    return const CameraFrame();
  }

  Future<void> _tick() async {
    if (_disposed) return;
    final api = ref.read(homeAssistantApiProvider);
    var next = cameraRefreshInterval;
    if (api == null) {
      state = CameraFrame(
        bytes: state.bytes,
        takenAt: state.takenAt,
        failing: true,
      );
      next = _retryAfterFailure;
    } else {
      try {
        final bytes = await api.fetchImage(
          '/api/camera_proxy/${Uri.encodeComponent(entityId)}',
        );
        if (_disposed) return;
        state = CameraFrame(bytes: bytes, takenAt: DateTime.now());
      } on Object catch (e) {
        if (_disposed) return;
        _log.info('Snapshot failed: ${e.runtimeType}');
        state = CameraFrame(
          bytes: state.bytes,
          takenAt: state.takenAt,
          failing: true,
        );
        next = _retryAfterFailure;
      }
    }
    if (!_disposed) _timer = Timer(next, _tick);
  }
}
