import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/app_preferences.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../kiosk/application/kiosk_now.dart';
import '../kiosk/application/kiosk_people.dart';
import '../kiosk/presentation/kiosk_motion.dart';

/// What falls across the wall panel.
enum Celebration { snow, confetti, halloween }

/// The season's decoration for [day], if any: snow from December to
/// Orthodox Christmas, confetti for New Year's Eve and Day, pumpkins the
/// week before Halloween.
Celebration? seasonFor(DateTime day) {
  final md = day.month * 100 + day.day;
  if (md == 1231 || md == 101) return Celebration.confetti;
  if (md >= 1201 || md <= 107) return Celebration.snow;
  if (md >= 1024 && md <= 1031) return Celebration.halloween;
  return null;
}

/// Household members whose birthday is today (set per member on the
/// wall panel).
final birthdaysTodayProvider = Provider<List<String>>((ref) {
  final now = ref.watch(kioskNowProvider);
  return [
    for (final e in ref.watch(kioskPeopleProvider).entries)
      if (e.value.birthday case (final m, final d)
          when m == now.month && d == now.day)
        e.key,
  ];
});

/// Seasonal decorations on the wall panel (on by default).
class SeasonalController extends Notifier<bool> {
  static const _key = 'kiosk.seasonal';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] != false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? null : {'enabled': false});
  }
}

final seasonalProvider = NotifierProvider<SeasonalController, bool>(
  SeasonalController.new,
);

/// Today's celebration: a birthday's confetti first, then the season's.
final celebrationProvider = Provider<Celebration?>((ref) {
  if (!ref.watch(seasonalProvider)) return null;
  if (ref.watch(birthdaysTodayProvider).isNotEmpty) {
    return Celebration.confetti;
  }
  return seasonFor(ref.watch(kioskNowProvider));
});

/// Falling snow, confetti or pumpkins over the wall panel; never in the
/// way of a tap. They fall for [showFor] after the panel wakes or is
/// touched, then fade away, so an idle panel is not drawing all day; and
/// never while the screen is dimmed or motion is reduced.
class CelebrationLayer extends ConsumerStatefulWidget {
  const CelebrationLayer({super.key});

  static const showFor = Duration(minutes: 1);

  @override
  ConsumerState<CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends ConsumerState<CelebrationLayer>
    with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  // About 25 pictures a second: slow snow needs no more, and the wall
  // panel is spared half the drawing.
  late final Ticker _ticker = createTicker((elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    if (t - _time.value >= 0.04 || t < _time.value) _time.value = t;
  });

  /// Falling now (else fading out, then still and gone).
  bool _falling = true;
  Timer? _quiet;

  @override
  void initState() {
    super.initState();
    _again();
  }

  /// A touch or waking up: let it fall for a while.
  void _again() {
    _quiet?.cancel();
    _quiet = Timer(CelebrationLayer.showFor, () {
      if (mounted) setState(() => _falling = false);
    });
    if (!_falling) setState(() => _falling = true);
  }

  @override
  void dispose() {
    _quiet?.cancel();
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(kioskDimmedProvider, (_, dimmed) {
      if (!dimmed) _again();
    });
    final kind = ref.watch(celebrationProvider);
    final moving = kioskMotion(context, ref);
    final run = kind != null && moving;
    if (!run && _ticker.isActive) _ticker.stop();
    // Touches pass through; they only start another fall.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _again(),
      child: !run
          ? const SizedBox.expand()
          : AnimatedOpacity(
              opacity: _falling ? 1 : 0,
              duration: const Duration(seconds: 3),
              onEnd: () {
                if (!_falling && _ticker.isActive) _ticker.stop();
              },
              child: Builder(
                builder: (context) {
                  if (_falling && !_ticker.isActive) _ticker.start();
                  return IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: ValueKey('celebration-${kind.name}'),
                        size: Size.infinite,
                        painter: _FallPainter(kind, _time),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Everything is a function of time: no per-frame state to keep.
class _FallPainter extends CustomPainter {
  _FallPainter(this.kind, this.time) : super(repaint: time);

  final Celebration kind;
  final ValueNotifier<double> time;

  static final _random = math.Random(7);
  static final _seeds = List.generate(
    70,
    (_) => [for (var i = 0; i < 5; i++) _random.nextDouble()],
  );
  static const _confetti = [
    Color(0xFFFF5A5F),
    Color(0xFFFFC233),
    Color(0xFF3D7BFF),
    Color(0xFF2DBE6C),
    Color(0xFFB065E8),
  ];

  int get _count => switch (kind) {
    Celebration.snow => 55,
    Celebration.confetti => 70,
    Celebration.halloween => 18,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final s = _seeds[i];
      // Seconds to cross the screen, and where along it this one is.
      final crossing = switch (kind) {
        Celebration.snow => 14 + 10 * s[0],
        Celebration.confetti => 7 + 5 * s[0],
        Celebration.halloween => 22 + 12 * s[0],
      };
      final y = ((s[1] + t / crossing) % 1) * (size.height + 60) - 30;
      final sway = math.sin(t * (0.6 + s[2]) + s[3] * 6.3) * 24;
      final x = s[4] * size.width + sway;
      switch (kind) {
        case Celebration.snow:
          paint.color = Colors.white.withValues(alpha: 0.35 + 0.4 * s[2]);
          canvas.drawCircle(Offset(x, y), 1.5 + 3 * s[3], paint);
        case Celebration.confetti:
          paint.color = _confetti[i % _confetti.length].withValues(alpha: 0.8);
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(t * (1 + 3 * s[2]) + s[3] * 6.3)
            ..drawRect(const Rect.fromLTWH(-4, -2, 8, 4), paint)
            ..restore();
        case Celebration.halloween:
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(math.sin(t + s[3] * 6) * 0.4);
          if (i.isEven) {
            // A little pumpkin: three orange lobes and a green stem.
            final r = 8 + 6 * s[2];
            paint.color = const Color(0xFFF07F1E).withValues(alpha: 0.85);
            for (final dx in [-r * 0.45, r * 0.45, 0.0]) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: Offset(dx, 0),
                  width: r * 1.3,
                  height: r * 1.6,
                ),
                paint,
              );
            }
            paint.color = const Color(0xFF3E7D2B);
            canvas.drawRect(
              Rect.fromLTWH(-r * 0.12, -r * 1.05, r * 0.24, r * 0.4),
              paint,
            );
          } else {
            // An autumn leaf.
            final r = 6 + 5 * s[2];
            paint.color =
                (i % 4 == 1 ? const Color(0xFFC8501E) : const Color(0xFFE0A030))
                    .withValues(alpha: 0.75);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: r * 1.1,
                height: r * 2.2,
              ),
              paint,
            );
          }
          canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_FallPainter old) => old.kind != kind;
}
