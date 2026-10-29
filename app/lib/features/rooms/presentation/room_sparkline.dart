import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';

/// The room's temperature sensor (the first by name), if it has one.
final roomTemperatureSensorProvider = Provider.family<String?, String?>((
  ref,
  roomId,
) {
  final ids = ref.watch(
    deviceIdsByRoomProvider.select((m) => m[roomId]?.toList() ?? const []),
  );
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final sensors = [
    for (final id in ids)
      if (devices[id] case final d?
          when d.kind == DeviceKind.temperatureSensor && d.available)
        d,
  ]..sort((a, b) => a.name.compareTo(b.name));
  return sensors.firstOrNull?.id;
});

/// The last 24 hours of a numeric sensor, at most ~48 points; kept for a
/// quarter of an hour so scrolling past a card does not fetch again.
final dayTrendProvider = FutureProvider.autoDispose
    .family<List<double>, String>((ref, entityId) async {
      final api = ref.watch(homeAssistantApiProvider);
      if (api == null) return const [];
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 15), link.close);
      ref.onDispose(timer.cancel);
      final now = DateTime.now();
      final points = await api.fetchHistory(
        entityId,
        now.subtract(const Duration(hours: 24)),
        now,
      );
      final values = [for (final p in points) ?double.tryParse(p.state)];
      if (values.length <= 48) return values;
      final step = values.length / 48;
      return [for (var i = 0; i < 48; i++) values[(i * step).floor()]];
    });

/// A thin line of the room's temperature over the last day; nothing while
/// it loads, offline, or when the room has no sensor.
class RoomSparkline extends ConsumerWidget {
  const RoomSparkline({
    super.key,
    required this.roomId,
    required this.color,
    this.width = 56,
    this.height = 22,
  });

  final String? roomId;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensor = ref.watch(roomTemperatureSensorProvider(roomId));
    if (sensor == null) return const SizedBox.shrink();
    final values = ref.watch(dayTrendProvider(sensor)).value ?? const [];
    if (values.length < 3) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: CustomPaint(
        key: ValueKey('roomSparkline-$roomId'),
        size: Size(width, height),
        painter: SparklinePainter(values, color),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    // A flat day stays a flat line in the middle, not a jagged one.
    if (hi - lo < 1) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.5;
      hi = mid + 0.5;
    }
    Offset at(int i) => Offset(
      i / (values.length - 1) * (size.width - 3),
      2 + (1 - (values[i] - lo) / (hi - lo)) * (size.height - 4),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      // Now.
      ..drawCircle(at(values.length - 1), 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.color != color || old.values != values;
}
