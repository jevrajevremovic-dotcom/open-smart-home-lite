import 'package:flutter/material.dart';

/// Fades the edges of a scrollable [child] where more content is hidden,
/// instead of cutting a chip or a line of text off with a hard edge.
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.extent = 28});

  /// A scrollable (scroll view, list); its axis decides which edges fade.
  final Widget child;
  final double extent;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  bool _start = false;
  bool _end = false;
  Axis _axis = Axis.vertical;

  bool _onMetrics(ScrollMetrics m) {
    final start = m.pixels > m.minScrollExtent + 1;
    final end = m.pixels < m.maxScrollExtent - 1;
    if (start != _start || end != _end || m.axis != _axis) {
      setState(() {
        _start = start;
        _end = end;
        _axis = m.axis;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final length = _axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final stop = length.isFinite && length > 0
            ? (widget.extent / length).clamp(0.0, 0.5)
            : 0.0;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: _axis == Axis.horizontal
                ? Alignment.centerLeft
                : Alignment.topCenter,
            end: _axis == Axis.horizontal
                ? Alignment.centerRight
                : Alignment.bottomCenter,
            colors: [
              _start ? Colors.transparent : Colors.white,
              Colors.white,
              Colors.white,
              _end ? Colors.transparent : Colors.white,
            ],
            stops: [0, stop, 1 - stop, 1],
          ).createShader(rect),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
