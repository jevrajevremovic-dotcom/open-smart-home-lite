import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../household/application/household_providers.dart';

/// Album art / channel logo from Home Assistant, or the device icon.
class MediaArtwork extends ConsumerWidget {
  const MediaArtwork({
    super.key,
    required this.deviceId,
    this.size = 56,
    this.radius = 12,
    this.background,
    this.iconColor,
  });

  final String deviceId;
  final double size;
  final double radius;
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deviceProvider(deviceId));
    if (d == null) return SizedBox.square(dimension: size);
    final path = d.metadata.picturePath;
    final bytes = path == null
        ? null
        : ref.watch(entityImageProvider(path)).value;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              )
            : ColoredBox(
                color: background ?? scheme.secondaryContainer,
                child: Icon(
                  d.state.raw == 'playing'
                      ? Icons.music_note
                      : DevicePresentation.icon(d),
                  size: size * 0.5,
                  color: iconColor ?? scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}
