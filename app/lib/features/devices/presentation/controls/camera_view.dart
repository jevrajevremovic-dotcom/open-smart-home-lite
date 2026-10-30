import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../core/widgets/status_widgets.dart';
import '../../data/local/camera_adapter.dart';
import '../../domain/smart_home_device.dart';

/// The camera's current image, renewed every 2 s while on screen.
class CameraView extends ConsumerWidget {
  const CameraView({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = device.deviceId;
    if (key == null) return const SizedBox.shrink();
    final frame = ref.watch(cameraFrameProvider(key));
    // The last image stays while the next one comes.
    final image = frame.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: image == null
                ? const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Image.memory(
                    image,
                    key: const Key('cameraImage'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
        ),
        if (frame.hasError) ...[
          const SizedBox(height: 8),
          InlineNotice.warning(context.l10n.cameraOffline),
        ],
      ],
    );
  }
}
