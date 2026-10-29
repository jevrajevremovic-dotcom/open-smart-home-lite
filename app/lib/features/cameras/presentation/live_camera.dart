import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/localization/l10n.dart';
import '../../authentication/application/session_controller.dart';

/// HLS playlist for a camera: WS `camera/stream` (frontend API) answers
/// with a short-lived, signed `/api/hls/<token>/master_playlist.m3u8`
/// path on the same server – no other host and no long-lived token.
final cameraStreamUrlProvider = FutureProvider.autoDispose.family<Uri, String>((
  ref,
  entityId,
) async {
  final ws = ref.watch(webSocketManagerProvider);
  final api = ref.watch(homeAssistantApiProvider);
  if (ws == null || api == null) throw StateError('not connected');
  final result = await ws.sendCommand({
    'type': 'camera/stream',
    'entity_id': entityId,
    'format': 'hls',
  });
  final url = result is Map ? result['url'] : null;
  if (url is! String || !url.startsWith('/api/hls/') || url.contains('..')) {
    throw StateError('unexpected stream url');
  }
  return api.address.baseUri.resolve(url);
});

/// Live video when the platform can play HLS (Android, iOS); otherwise or
/// on any error the caller shows snapshots instead.
bool get liveVideoSupported => !kIsWeb;

class LiveCameraView extends ConsumerStatefulWidget {
  const LiveCameraView({super.key, required this.cameraId, this.fallback});

  final String cameraId;

  /// Shown while the video starts and instead of the error when it cannot
  /// play (e.g. snapshots), so the screen is never empty.
  final Widget? fallback;

  @override
  ConsumerState<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends ConsumerState<LiveCameraView> {
  VideoPlayerController? _controller;
  Uri? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(cameraStreamUrlProvider(widget.cameraId), (_, next) {
      if (next case AsyncData(:final value)) _open(value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open(Uri url) async {
    if (_url == url) return;
    _url = url;
    final old = _controller;
    final controller = VideoPlayerController.networkUrl(url);
    _controller = controller;
    await old?.dispose();
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = ref.watch(cameraStreamUrlProvider(widget.cameraId));
    final controller = _controller;
    final failed = _failed || url.hasError;
    final playing = controller != null && controller.value.isInitialized;
    final fallback = widget.fallback;
    if (fallback != null && (failed || !playing)) {
      return KeyedSubtree(
        key: const Key('cameraLiveFallback'),
        child: fallback,
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.cameraLiveFailed,
                  key: const Key('cameraLiveFailed'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : controller != null && controller.value.isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
    );
  }
}
