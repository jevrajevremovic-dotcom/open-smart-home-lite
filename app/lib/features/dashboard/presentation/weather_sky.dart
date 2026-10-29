import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/application/device_providers.dart';
import '../../weather/application/weather_providers.dart';
import '../../weather/domain/weather.dart';

/// The colour of the sky outside, for a faint wash behind the greeting:
/// warm in sunshine, grey-blue in rain, deep blue at night.
Color skyColor(WeatherCondition? condition, {required bool night}) {
  if (night || condition == WeatherCondition.clearNight) {
    return const Color(0xFF2B3A67);
  }
  return switch (condition) {
    WeatherCondition.clearDay => const Color(0xFFFFB74D),
    WeatherCondition.partlyCloudy => const Color(0xFF9FC3E8),
    WeatherCondition.cloudy || WeatherCondition.fog => const Color(0xFF9AA5B1),
    WeatherCondition.rain ||
    WeatherCondition.heavyRain => const Color(0xFF5B8DB8),
    WeatherCondition.snow ||
    WeatherCondition.sleet ||
    WeatherCondition.hail => const Color(0xFFB8D8F0),
    WeatherCondition.thunderstorm => const Color(0xFF6A5ACD),
    WeatherCondition.windy => const Color(0xFF7FB8B0),
    _ => const Color(0x00000000),
  };
}

/// A soft gradient of [skyColor] fading downwards; transparent without
/// weather. Faint enough that text on it keeps its contrast.
class WeatherSky extends ConsumerWidget {
  const WeatherSky({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final condition = ref.watch(
      homeWeatherProvider.select((w) => w?.now.condition),
    );
    final night =
        ref.watch(deviceProvider('sun.sun'))?.state.raw == 'below_horizon';
    final color = skyColor(condition, night: night);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      key: const Key('weatherSky'),
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: color.a * (dark ? 0.28 : 0.22)),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
