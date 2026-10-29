import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/kiosk_controller.dart';

/// Whether the wall panel may move: not when the system asks for fewer
/// animations, and not while the screen is dimmed (no work for no one).
bool kioskMotion(BuildContext context, WidgetRef ref) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
    !ref.watch(kioskDimmedProvider);

/// Rises and fades in a little after the one before it ([index]), so a
/// room's cards arrive as a wave.
class StaggeredEntrance extends ConsumerStatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  ConsumerState<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends ConsumerState<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // At most ~0.4 s for the last card, however many there are.
    Future<void>.delayed(
      Duration(milliseconds: math.min(widget.index, 10) * 40),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kioskMotion(context, ref)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A short glow in [color] when [on] becomes true (a light turned on).
class OnGlow extends ConsumerStatefulWidget {
  const OnGlow({
    super.key,
    required this.on,
    required this.color,
    required this.radius,
    required this.child,
  });

  final bool on;
  final Color color;
  final double radius;
  final Widget child;

  @override
  ConsumerState<OnGlow> createState() => _OnGlowState();
}

class _OnGlowState extends ConsumerState<OnGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(OnGlow old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on && kioskMotion(context, ref)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      // Up quickly, down slowly: a breath.
      final t = _c.value;
      final strength = t < 0.3 ? t / 0.3 : (1 - t) / 0.7;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            if (_c.isAnimating)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55 * strength),
                blurRadius: 28 * strength,
                spreadRadius: 3 * strength,
              ),
          ],
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}

/// What the icon of [d] does while it works.
enum _IconMotion { none, spin, flicker, slowSpin, bobUp, bobDown }

_IconMotion _motionOf(SmartHomeDevice d) {
  final s = d.state;
  if (!d.available) return _IconMotion.none;
  switch (d.kind) {
    case DeviceKind.climate || DeviceKind.thermostat:
      return switch (s.hvacAction) {
        'heating' => _IconMotion.flicker,
        'cooling' => _IconMotion.slowSpin,
        _ => _IconMotion.none,
      };
    case DeviceKind.fan || DeviceKind.airPurifier:
      return s.isOn == true ? _IconMotion.spin : _IconMotion.none;
    case DeviceKind.vacuum:
      return s.raw == 'cleaning' ? _IconMotion.spin : _IconMotion.none;
    case DeviceKind.blind || DeviceKind.curtain || DeviceKind.garageDoor:
      return switch (s.coverState) {
        CoverState.opening => _IconMotion.bobUp,
        CoverState.closing => _IconMotion.bobDown,
        _ => _IconMotion.none,
      };
    default:
      return _IconMotion.none;
  }
}

/// A device's icon that shows it is working: a fan turns, heating
/// flickers, cooling turns slowly, a blind moves its way.
class LiveDeviceIcon extends ConsumerStatefulWidget {
  const LiveDeviceIcon({
    super.key,
    required this.device,
    required this.color,
    this.size = 24,
  });

  final SmartHomeDevice device;
  final Color color;
  final double size;

  @override
  ConsumerState<LiveDeviceIcon> createState() => _LiveDeviceIconState();
}

class _LiveDeviceIconState extends ConsumerState<LiveDeviceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final motion = kioskMotion(context, ref) ? _motionOf(d) : _IconMotion.none;
    final icon = Icon(
      motion == _IconMotion.flicker
          ? Icons.local_fire_department_outlined
          : motion == _IconMotion.slowSpin
          ? Icons.ac_unit
          : DevicePresentation.icon(d),
      color: widget.color,
      size: widget.size,
    );
    if (motion == _IconMotion.none) {
      if (_c.isAnimating) _c.stop();
      return icon;
    }
    final period = switch (motion) {
      _IconMotion.spin => const Duration(milliseconds: 1400),
      _IconMotion.slowSpin => const Duration(seconds: 8),
      _IconMotion.flicker => const Duration(milliseconds: 1600),
      _ => const Duration(milliseconds: 1200),
    };
    if (_c.duration != period || !_c.isAnimating) {
      _c
        ..duration = period
        ..repeat();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          final wave = math.sin(t * 2 * math.pi);
          return switch (motion) {
            _IconMotion.spin || _IconMotion.slowSpin => Transform.rotate(
              angle: t * 2 * math.pi,
              child: child,
            ),
            _IconMotion.flicker => Transform.scale(
              scale: 1 + 0.08 * wave.abs(),
              child: Opacity(opacity: 0.8 + 0.2 * wave.abs(), child: child),
            ),
            _IconMotion.bobUp => Transform.translate(
              offset: Offset(0, -3 * (t * 2 - 1).abs()),
              child: child,
            ),
            _IconMotion.bobDown => Transform.translate(
              offset: Offset(0, 3 * (t * 2 - 1).abs()),
              child: child,
            ),
            _IconMotion.none => child!,
          };
        },
        child: icon,
      ),
    );
  }
}

/// Three little bars dancing: music is playing.
class EqualizerBars extends ConsumerStatefulWidget {
  const EqualizerBars({super.key, required this.color, this.height = 14});

  final Color color;
  final double height;

  @override
  ConsumerState<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends ConsumerState<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = kioskMotion(context, ref);
    if (moving && !_c.isAnimating) _c.repeat();
    if (!moving && _c.isAnimating) _c.stop();
    final h = widget.height;
    return SizedBox(
      key: const Key('equalizerBars'),
      width: h,
      height: h,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: h / 4.5,
                height:
                    h *
                    (0.3 +
                        0.7 *
                            (moving
                                ? (math
                                      .sin((_c.value + i * 0.33) * 2 * math.pi)
                                      .abs())
                                : 0.5)),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A number that counts to its new value instead of jumping.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Text(format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(format(v), style: style),
    );
  }
}
