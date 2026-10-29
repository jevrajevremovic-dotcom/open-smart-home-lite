import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_presentation.dart';

/// Warm white, for a light the scene turns on without saying its colour.
const _warmWhite = Color(0xFFFFD08A);

/// The colours a scene's lights get, from its config in Home Assistant
/// (UI scenes only; YAML scenes and scenes without lights give none).
/// Kept for half an hour.
final sceneColorsProvider = FutureProvider.autoDispose
    .family<List<Color>, String>((ref, sceneEntityId) async {
      final configId = ref.watch(
        deviceProvider(sceneEntityId).select((d) => d?.metadata.configId),
      );
      final api = ref.watch(homeAssistantApiProvider);
      if (configId == null || api == null) return const [];
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 30), link.close);
      ref.onDispose(timer.cancel);
      final Map<String, Object?> config;
      try {
        config = await api.fetchScene(configId);
      } on Object {
        return const [];
      }
      final entities = config['entities'];
      if (entities is! Map) return const [];
      return [
        for (final e in entities.entries)
          if ('${e.key}'.startsWith('light.') &&
              e.value is Map &&
              (e.value as Map)['state'] == 'on')
            sceneLightColor(e.value as Map),
      ];
    });

/// One light's colour in a scene config (`rgb_color`, `hs_color`,
/// `color_temp_kelvin` or mireds), else warm white.
Color sceneLightColor(Map<Object?, Object?> s) {
  if (s['rgb_color'] case [final num r, final num g, final num b]) {
    return Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  }
  if (s['hs_color'] case [final num h, final num sat]) {
    return HSVColor.fromAHSV(1, h.toDouble() % 360, sat / 100, 1).toColor();
  }
  if (s['color_temp_kelvin'] case final num k) {
    return DevicePresentation.kelvinColor(k.toInt());
  }
  if (s['color_temp'] case final num mired when mired > 0) {
    return DevicePresentation.kelvinColor(1000000 ~/ mired);
  }
  return _warmWhite;
}

/// A scene's look: its lights' colours around a circle, or its icon.
class SceneSwatch extends ConsumerWidget {
  const SceneSwatch({
    super.key,
    required this.sceneId,
    required this.icon,
    this.size = 56,
    this.fallback,
  });

  final String sceneId;
  final IconData icon;
  final double size;

  /// Background without colours.
  final Color? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ref.watch(sceneColorsProvider(sceneId)).value ?? const [];
    final Decoration decoration = colors.isEmpty
        ? BoxDecoration(
            shape: BoxShape.circle,
            color: fallback ?? scheme.surfaceContainerHighest,
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            gradient: colors.length == 1
                ? RadialGradient(
                    colors: [
                      colors.first,
                      colors.first.withValues(alpha: 0.55),
                    ],
                  )
                : SweepGradient(colors: [...colors, colors.first]),
          );
    return AnimatedContainer(
      key: ValueKey('sceneSwatch-$sceneId-${colors.length}'),
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: decoration,
      child: Icon(
        icon,
        size: size * 0.42,
        color: colors.isEmpty ? scheme.onSurface : Colors.white,
        shadows: colors.isEmpty
            ? null
            : const [Shadow(color: Colors.black45, blurRadius: 6)],
      ),
    );
  }
}
