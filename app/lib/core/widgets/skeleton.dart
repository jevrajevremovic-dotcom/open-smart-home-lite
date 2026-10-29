import 'package:flutter/material.dart';

import 'responsive.dart';

/// Placeholder shapes shown while the first data loads, so the screen keeps
/// its layout instead of jumping from a spinner to content. A soft light
/// sweeps across them, unless the system asks for reduced motion.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.label});

  final Widget child;

  /// Read by screen readers instead of the shapes.
  final String? label;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final light = Color.lerp(base, scheme.surface, 0.6)!;
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 3 - 1; // -1 … 2: sweep left to right
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(t - 1, -0.3),
              end: Alignment(t + 1, 0.3),
              colors: [base, light, base],
            ).createShader(rect),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// One placeholder shape; give it the size of what it stands for.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// The home screen before the first snapshot: summary tiles, a weather card
/// and room cards.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: label,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TileWrap(
              children: [
                for (var i = 0; i < 6; i++)
                  const SkeletonBox(height: 64, radius: 20),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonBox(height: 170, radius: 24),
            const SizedBox(height: 24),
            const SkeletonBox(width: 120, height: 18),
            const SizedBox(height: 12),
            const TileWrap(
              children: [
                SkeletonBox(height: 120, radius: 24),
                SkeletonBox(height: 120, radius: 24),
                SkeletonBox(height: 120, radius: 24),
                SkeletonBox(height: 120, radius: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of rows (activity, history, details) before it loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 6, this.label});

  final int rows;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: label,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const SkeletonBox(width: 40, height: 40, radius: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.7 : 0.5,
                            child: const SkeletonBox(height: 14),
                          ),
                          const SizedBox(height: 8),
                          const FractionallySizedBox(
                            widthFactor: 0.35,
                            child: SkeletonBox(height: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
