import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/weather.dart';
import 'weather_labels.dart';

/// The current weather's icon, gently alive: the sun turns, clouds drift,
/// rain falls, snow spins, lightning flickers. Still when the system asks
/// for fewer animations.
class AnimatedWeatherIcon extends StatefulWidget {
  const AnimatedWeatherIcon({
    super.key,
    required this.condition,
    required this.size,
    this.color,
  });

  final WeatherCondition condition;
  final double size;
  final Color? color;

  @override
  State<AnimatedWeatherIcon> createState() => _AnimatedWeatherIconState();
}

class _AnimatedWeatherIconState extends State<AnimatedWeatherIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _period(widget.condition),
  );

  static Duration _period(WeatherCondition c) => switch (c) {
    WeatherCondition.clearDay => const Duration(seconds: 24),
    WeatherCondition.snow ||
    WeatherCondition.sleet ||
    WeatherCondition.hail => const Duration(seconds: 12),
    WeatherCondition.rain ||
    WeatherCondition.heavyRain => const Duration(milliseconds: 1400),
    WeatherCondition.thunderstorm => const Duration(seconds: 4),
    _ => const Duration(seconds: 6),
  };

  bool get _animated => switch (widget.condition) {
    WeatherCondition.exceptional || WeatherCondition.unknown => false,
    _ => true,
  };

  bool _still = true;

  /// Runs the animation only when it is wanted and visible.
  void _sync() {
    _still =
        !_animated ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    if (_still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedWeatherIcon old) {
    super.didUpdateWidget(old);
    if (old.condition != widget.condition) {
      _c
        ..stop()
        ..duration = _period(widget.condition);
      _sync();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? IconTheme.of(context).color;
    final size = widget.size;
    if (_still) {
      return Icon(weatherIcon(widget.condition), size: size, color: color);
    }
    final rain =
        widget.condition == WeatherCondition.rain ||
        widget.condition == WeatherCondition.heavyRain;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final wave = math.sin(t * 2 * math.pi);
            switch (widget.condition) {
              case WeatherCondition.clearDay:
                return Transform.rotate(
                  angle: t * 2 * math.pi,
                  child: Icon(
                    Icons.wb_sunny_outlined,
                    size: size,
                    color: color,
                  ),
                );
              case WeatherCondition.snow ||
                  WeatherCondition.sleet ||
                  WeatherCondition.hail:
                return Transform.rotate(
                  angle: t * 2 * math.pi,
                  child: Icon(Icons.ac_unit, size: size, color: color),
                );
              case WeatherCondition.clearNight:
                return Transform.scale(
                  scale: 1 + 0.05 * wave,
                  child: Icon(
                    Icons.nightlight_outlined,
                    size: size,
                    color: color,
                  ),
                );
              case WeatherCondition.thunderstorm:
                // Two quick flickers, then calm.
                final flash = (t > 0.1 && t < 0.14) || (t > 0.2 && t < 0.24);
                return Opacity(
                  opacity: flash ? 0.35 : 1,
                  child: Icon(
                    Icons.thunderstorm_outlined,
                    size: size,
                    color: color,
                  ),
                );
              case _ when rain:
                return CustomPaint(
                  painter: _RainPainter(
                    t,
                    color ?? Colors.blue,
                    heavy: widget.condition == WeatherCondition.heavyRain,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.cloud_outlined,
                      size: size * 0.72,
                      color: color,
                    ),
                  ),
                );
              default:
                // Clouds, fog and wind drift side to side.
                return Opacity(
                  opacity: widget.condition == WeatherCondition.fog
                      ? 0.75 + 0.25 * wave
                      : 1,
                  child: Transform.translate(
                    offset: Offset(size * 0.06 * wave, 0),
                    child: Icon(
                      weatherIcon(widget.condition),
                      size: size,
                      color: color,
                    ),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

/// Short streaks falling under the cloud.
class _RainPainter extends CustomPainter {
  _RainPainter(this.t, this.color, {required this.heavy});

  final double t;
  final Color color;
  final bool heavy;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    final drops = heavy ? 4 : 3;
    final top = size.height * 0.55;
    final fall = size.height * 0.4;
    for (var i = 0; i < drops; i++) {
      final phase = (t + i / drops) % 1;
      final x = size.width * (0.28 + 0.44 * i / (drops - 1)) - phase * 4;
      final y = top + phase * fall;
      paint.color = color.withValues(alpha: (1 - phase).clamp(0, 1));
      canvas.drawLine(
        Offset(x, y),
        Offset(x - size.width * 0.04, y + size.height * 0.12),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.t != t || old.color != color;
}
