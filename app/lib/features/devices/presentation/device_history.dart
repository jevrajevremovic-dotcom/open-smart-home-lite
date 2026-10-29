import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/localization/l10n.dart';
import '../../../app/theme/app_theme.dart';
import '../../../integrations/home_assistant/models/ha_history.dart';
import '../../authentication/application/session_controller.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';
import 'device_presentation.dart';
import '../../../core/widgets/skeleton.dart';

enum HistoryRange {
  day(Duration(hours: 24)),
  week(Duration(days: 7));

  const HistoryRange(this.span);
  final Duration span;
}

final deviceHistoryProvider = FutureProvider.autoDispose
    .family<List<HaHistoryPoint>, (String, HistoryRange)>((ref, key) async {
      final api = ref.watch(homeAssistantApiProvider);
      if (api == null) return const [];
      final end = DateTime.now();
      return api.fetchHistory(key.$1, end.subtract(key.$2.span), end);
    });

final deviceLogbookProvider = FutureProvider.autoDispose
    .family<List<HaLogbookEntry>, String>((ref, entityId) async {
      final api = ref.watch(homeAssistantApiProvider);
      if (api == null) return const [];
      final end = DateTime.now();
      return api.fetchLogbook(
        entityId,
        end.subtract(const Duration(hours: 24)),
        end,
      );
    });

/// Devices whose history is worth showing.
bool hasHistory(SmartHomeDevice d) =>
    !d.kind.isRoutine &&
    d.kind != DeviceKind.camera &&
    d.kind != DeviceKind.button &&
    d.kind != DeviceKind.weather &&
    d.kind != DeviceKind.unknown;

/// Localised label for a raw Home Assistant state in history/activity;
/// with [kind], `on`/`off` of a sensor read as "Open", "Motion detected"…
String historyStateLabel(
  AppLocalizations l10n,
  String state, [
  DeviceKind? kind,
]) {
  if (state == 'on' || state == 'off') {
    final on = state == 'on';
    final pair = switch (kind) {
      DeviceKind.contactSensor => (l10n.contactOpen, l10n.contactClosed),
      DeviceKind.motionSensor => (l10n.motionDetected, l10n.motionClear),
      DeviceKind.occupancySensor => (
        l10n.occupancyDetected,
        l10n.occupancyClear,
      ),
      DeviceKind.smokeSensor => (l10n.smokeDetected, l10n.smokeClear),
      DeviceKind.coSensor => (l10n.coDetected, l10n.coClear),
      DeviceKind.waterLeakSensor => (l10n.leakDetected, l10n.leakClear),
      DeviceKind.vibrationSensor => (
        l10n.vibrationDetected,
        l10n.vibrationClear,
      ),
      DeviceKind.binarySensor => (l10n.binaryActive, l10n.binaryInactive),
      _ => null,
    };
    if (pair != null) return on ? pair.$1 : pair.$2;
  }
  return switch (state) {
    'on' => l10n.stateOn,
    'off' => l10n.stateOff,
    'open' => l10n.contactOpen,
    'closed' => l10n.contactClosed,
    'locked' => l10n.lockLocked,
    'unlocked' => l10n.lockUnlocked,
    'home' => l10n.personHome,
    'not_home' => l10n.personAway,
    'unavailable' => l10n.stateUnavailable,
    _ => state,
  };
}

/// History chart (numbers) or timeline (states), plus recent activity.
class DeviceHistorySection extends ConsumerStatefulWidget {
  const DeviceHistorySection({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  ConsumerState<DeviceHistorySection> createState() =>
      _DeviceHistorySectionState();
}

class _DeviceHistorySectionState extends ConsumerState<DeviceHistorySection> {
  HistoryRange _range = HistoryRange.day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = widget.device;
    final history = ref.watch(deviceHistoryProvider((d.id, _range)));
    final numeric = d.state.numericValue != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.historyTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            SegmentedButton<HistoryRange>(
              key: const Key('historyRange'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: HistoryRange.day,
                  label: Text(l10n.history24h),
                ),
                ButtonSegment(
                  value: HistoryRange.week,
                  label: Text(l10n.history7d),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: switch (history) {
              AsyncData(value: final points) when points.isEmpty => Text(
                l10n.historyEmpty,
              ),
              AsyncData(value: final points) =>
                numeric
                    ? NumericHistoryChart(
                        key: const Key('historyChart'),
                        points: points,
                        unit: d.state.unit,
                        range: _range,
                      )
                    : StateTimeline(
                        key: const Key('historyTimeline'),
                        points: points,
                        range: _range,
                        color: context.deviceAccents
                            .of(DevicePresentation.accent(d))
                            .icon,
                      ),
              AsyncError() => Text(l10n.historyUnavailable),
              _ => Shimmer(
                label: l10n.loadingContent,
                child: const SkeletonBox(height: 120, radius: 16),
              ),
            },
          ),
        ),
        if (!numeric) ...[
          const SizedBox(height: 16),
          Text(l10n.activityTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Activity(entityId: d.id, kind: d.kind),
        ],
      ],
    );
  }
}

class _Activity extends ConsumerWidget {
  const _Activity({required this.entityId, required this.kind});

  final String entityId;
  final DeviceKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final log = ref.watch(deviceLogbookProvider(entityId));
    final time = DateFormat.Hm(l10n.localeName);
    return switch (log) {
      AsyncData(value: final entries) when entries.isEmpty => Text(
        l10n.activityEmpty,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      AsyncData(value: final entries) => Card(
        child: Column(
          key: const Key('activityList'),
          children: [
            for (final e in entries.take(10))
              ListTile(
                dense: true,
                leading: Text(
                  time.format(e.when),
                  style: theme.textTheme.labelLarge,
                ),
                title: Text(
                  e.state != null
                      ? historyStateLabel(l10n, e.state!, kind)
                      : (e.message ?? ''),
                ),
                trailing: e.byUser
                    ? Tooltip(
                        message: l10n.activityByUser,
                        child: const Icon(Icons.person_outline, size: 18),
                      )
                    : null,
              ),
          ],
        ),
      ),
      AsyncError() => Text(l10n.historyUnavailable),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Line chart of a numeric sensor with min/max and a scrub-to-read value.
class NumericHistoryChart extends StatefulWidget {
  const NumericHistoryChart({
    super.key,
    required this.points,
    required this.range,
    this.unit,
  });

  final List<HaHistoryPoint> points;
  final HistoryRange range;
  final String? unit;

  @override
  State<NumericHistoryChart> createState() => _NumericHistoryChartState();
}

class _NumericHistoryChartState extends State<NumericHistoryChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final values = <(DateTime, double)>[
      for (final p in widget.points)
        if (double.tryParse(p.state) case final v?) (p.at, v),
    ];
    if (values.isEmpty) return Text(l10n.historyEmpty);
    final lo = values.map((v) => v.$2).reduce(math.min);
    final hi = values.map((v) => v.$2).reduce(math.max);
    String fmt(double v) => formatNumber(
      locale,
      v,
      unit: widget.unit == null ? null : ' ${widget.unit}',
    );
    final sel = _selected == null ? null : values[_selected!];
    final dateFmt = widget.range == HistoryRange.day
        ? DateFormat.Hm(locale)
        : DateFormat.MMMEd(locale).add_Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sel == null
              ? '${l10n.historyMin(fmt(lo))}   ${l10n.historyMax(fmt(hi))}'
              : '${dateFmt.format(sel.$1)} · ${fmt(sel.$2)}',
          key: const Key('historyCaption'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            void pick(Offset p) {
              final start = values.first.$1;
              final span = values.last.$1.difference(start).inMilliseconds;
              final t = span == 0 ? 0.0 : (p.dx / c.maxWidth).clamp(0.0, 1.0);
              final target = start.add(
                Duration(milliseconds: (span * t).round()),
              );
              var best = 0;
              for (var i = 1; i < values.length; i++) {
                if ((values[i].$1.difference(target)).abs() <
                    (values[best].$1.difference(target)).abs()) {
                  best = i;
                }
              }
              setState(() => _selected = best);
            }

            return Semantics(
              label:
                  '${l10n.historyTitle}: ${l10n.historyMin(fmt(lo))}, ${l10n.historyMax(fmt(hi))}',
              child: GestureDetector(
                onPanDown: (e) => pick(e.localPosition),
                onPanUpdate: (e) => pick(e.localPosition),
                onPanEnd: (_) => setState(() => _selected = null),
                onTapUp: (_) => setState(() => _selected = null),
                child: CustomPaint(
                  size: Size(c.maxWidth, 160),
                  painter: _LinePainter(
                    values: values,
                    lo: lo,
                    hi: hi,
                    selected: _selected,
                    line: theme.colorScheme.primary,
                    grid: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateFmt.format(values.first.$1),
              style: theme.textTheme.labelSmall,
            ),
            Text(
              dateFmt.format(values.last.$1),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.lo,
    required this.hi,
    required this.selected,
    required this.line,
    required this.grid,
  });

  final List<(DateTime, double)> values;
  final double lo;
  final double hi;
  final int? selected;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final start = values.first.$1;
    final span = math.max(1, values.last.$1.difference(start).inMilliseconds);
    final pad = (hi - lo) * 0.1 + 0.001;
    Offset at(int i) {
      final x =
          values[i].$1.difference(start).inMilliseconds / span * size.width;
      final y =
          size.height -
          (values[i].$2 - (lo - pad)) / ((hi + pad) - (lo - pad)) * size.height;
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        gridPaint,
      );
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = line.withValues(alpha: 0.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    if (selected != null) {
      final p = at(selected!);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = line.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.selected != selected || old.line != line;
}

/// On/off-like history as coloured segments on a time bar.
class StateTimeline extends StatelessWidget {
  const StateTimeline({
    super.key,
    required this.points,
    required this.range,
    required this.color,
  });

  final List<HaHistoryPoint> points;
  final HistoryRange range;
  final Color color;

  static const _active = {'on', 'open', 'unlocked', 'home', 'playing'};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final end = DateTime.now();
    final start = end.subtract(range.span);
    final total = end.difference(start).inMilliseconds;
    final fmt = range == HistoryRange.day
        ? DateFormat.Hm(l10n.localeName)
        : DateFormat.E(l10n.localeName);
    final segments = <(double, double, String)>[];
    for (var i = 0; i < points.length; i++) {
      final from = points[i].at.isBefore(start) ? start : points[i].at;
      final to = i + 1 < points.length ? points[i + 1].at : end;
      if (!to.isAfter(from)) continue;
      segments.add((
        from.difference(start).inMilliseconds / total,
        to.difference(start).inMilliseconds / total,
        points[i].state,
      ));
    }
    final activeShare = segments
        .where((s) => _active.contains(s.$3))
        .fold<double>(0, (a, s) => a + (s.$2 - s.$1));

    return Semantics(
      label:
          '${l10n.historyTitle}: ${l10n.stateOn} ${(activeShare * 100).round()} %',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 28,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  for (final (a, b, s) in segments)
                    if (_active.contains(s))
                      Positioned(
                        left: a * c.maxWidth,
                        width: math.max(2, (b - a) * c.maxWidth),
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt.format(start), style: theme.textTheme.labelSmall),
              Text(
                fmt.format(start.add(range.span ~/ 2)),
                style: theme.textTheme.labelSmall,
              ),
              Text(fmt.format(end), style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
