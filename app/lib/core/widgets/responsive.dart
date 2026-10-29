import 'package:flutter/widgets.dart';

/// Width classes, aligned with Material 3 window size classes.
enum WindowSize {
  /// Phones in portrait.
  compact,

  /// Large phones in landscape, small tablets.
  medium,

  /// Tablets.
  expanded,

  /// Large tablets and wall panels.
  large;

  static WindowSize fromWidth(double width) {
    if (width < Breakpoints.medium) return compact;
    if (width < Breakpoints.expanded) return medium;
    if (width < Breakpoints.large) return expanded;
    return large;
  }

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Suggested number of grid columns for dashboard cards.
  int get gridColumns => switch (this) {
    compact => 1,
    medium => 2,
    expanded => 3,
    large => 4,
  };

  bool get usesNavigationRail => this != compact;
}

/// The only place breakpoint values are defined.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  /// Max width of single-column forms (onboarding, settings) on wide screens.
  static const double formMaxWidth = 560;
}

/// Centers [child] and limits its width; used for forms on tablets.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.formMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Stat tiles: two equal columns on phones (an odd last tile takes the whole
/// row), natural widths on larger screens.
class TileWrap extends StatelessWidget {
  const TileWrap({super.key, required this.children, this.spacing = 12});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (WindowSize.fromWidth(width) != WindowSize.compact) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children,
          );
        }
        final half = (width - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (i, child) in children.indexed)
              SizedBox(
                width: children.length.isOdd && i == children.length - 1
                    ? width
                    : half,
                child: child,
              ),
          ],
        );
      },
    );
  }
}
