import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_page.dart';

/// Paper with a dot grid, the page's strokes and the line being drawn.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.strokes,
    required this.dark,
    this.current,
    this.dots = true,
  });

  final List<BoardStroke> strokes;
  final BoardStroke? current;
  final bool dark;
  final bool dots;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / boardWidth;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF23201C) : boardPaper,
    );
    if (dots) {
      final dot = Paint()
        ..color = dark ? const Color(0x33FFFFFF) : const Color(0x33000000);
      const step = 50.0;
      final r = math.max(1.0, 2 * scale);
      for (var x = step; x < boardWidth; x += step) {
        for (var y = step; y < boardHeight; y += step) {
          canvas.drawCircle(Offset(x, y) * scale, r, dot);
        }
      }
    }
    paintStrokes(canvas, [...strokes, ?current], scale: scale, dark: dark);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.strokes != strokes ||
      old.current != current ||
      old.dark != dark ||
      old.dots != dots;
}

/// A page drawn small (lists, kiosk panel); not interactive.
class BoardThumbnail extends StatelessWidget {
  const BoardThumbnail({super.key, required this.page});

  final BoardPage page;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: boardWidth / boardHeight,
    child: CustomPaint(
      painter: BoardPainter(
        strokes: page.strokes,
        dark: Theme.of(context).brightness == Brightness.dark,
        dots: false,
      ),
    ),
  );
}

enum BoardTool { pen, eraser }

/// The drawing surface: one finger (or a stylus) draws or erases, two
/// fingers zoom and move the page.
class BoardCanvas extends StatefulWidget {
  const BoardCanvas({
    super.key,
    required this.strokes,
    required this.tool,
    required this.color,
    required this.width,
    required this.onStroke,
    required this.onErase,
  });

  final List<BoardStroke> strokes;
  final BoardTool tool;
  final int color;
  final double width;

  /// A finished line.
  final ValueChanged<BoardStroke> onStroke;

  /// Strokes touched by the eraser (indexes into [strokes]).
  final ValueChanged<Set<int>> onErase;

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  final Map<int, Offset> _pointers = {};
  List<Offset>? _points;
  int? _drawingPointer;

  // Zoom and pan (on top of fitting the page to the view).
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double? _pinchStartDistance;
  double _pinchStartZoom = 1;
  Offset? _pinchStartFocal;
  Offset _pinchStartPan = Offset.zero;

  late double _fit;
  late Offset _origin;

  Offset _toPage(Offset local) => (local - _origin - _pan) / (_fit * _zoom);

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _drawingPointer = e.pointer;
      _points = [_toPage(e.localPosition)];
      if (widget.tool == BoardTool.eraser) _erase(_points!.last);
    } else {
      // A second finger: zoom/pan instead of drawing.
      _drawingPointer = null;
      _points = null;
      final p = _pointers.values.toList();
      _pinchStartDistance = (p[0] - p[1]).distance;
      _pinchStartZoom = _zoom;
      _pinchStartFocal = (p[0] + p[1]) / 2;
      _pinchStartPan = _pan;
    }
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2 && _pinchStartDistance != null) {
      final p = _pointers.values.toList();
      final distance = (p[0] - p[1]).distance;
      final focal = (p[0] + p[1]) / 2;
      final zoom = (_pinchStartZoom * distance / _pinchStartDistance!).clamp(
        1.0,
        4.0,
      );
      // Keep the point under the fingers in place while zooming.
      final start = _pinchStartFocal!;
      final anchor = (start - _origin - _pinchStartPan) / _pinchStartZoom;
      setState(() {
        _zoom = zoom;
        _pan = focal - _origin - anchor * zoom;
      });
      return;
    }
    if (e.pointer != _drawingPointer || _points == null) return;
    final at = _toPage(e.localPosition);
    if (widget.tool == BoardTool.eraser) {
      _erase(at);
    } else if ((at - _points!.last).distance >= 1.5) {
      setState(() => _points = [..._points!, at]);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
    if (e.pointer != _drawingPointer) return;
    final points = _points;
    _drawingPointer = null;
    _points = null;
    if (points != null && widget.tool == BoardTool.pen) {
      widget.onStroke(
        BoardStroke(color: widget.color, width: widget.width, points: points),
      );
    }
    setState(() {});
  }

  void _erase(Offset at) {
    final hit = <int>{
      for (var i = 0; i < widget.strokes.length; i++)
        if (widget.strokes[i].hits(at, 14)) i,
    };
    if (hit.isNotEmpty) widget.onErase(hit);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, c) {
        _fit = math.min(c.maxWidth / boardWidth, c.maxHeight / boardHeight);
        final size = Size(boardWidth * _fit, boardHeight * _fit);
        _origin = Offset(
          (c.maxWidth - size.width) / 2,
          (c.maxHeight - size.height) / 2,
        );
        final points = _points;
        return Listener(
          key: const Key('boardCanvas'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: _origin.dx + _pan.dx,
                  top: _origin.dy + _pan.dy,
                  width: size.width * _zoom,
                  height: size.height * _zoom,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: BoardPainter(
                        strokes: widget.strokes,
                        dark: dark,
                        current: points == null || widget.tool != BoardTool.pen
                            ? null
                            : BoardStroke(
                                color: widget.color,
                                width: widget.width,
                                points: points,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
