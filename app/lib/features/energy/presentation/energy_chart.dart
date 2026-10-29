import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../data/energy_repository.dart';
import 'energy_format.dart';

/// Single-series bar chart of consumption per hour/day.
///
/// One hue (it is one series, so no legend), thin rounded bars anchored to
/// the baseline with a gap between them, recessive axis, a value label on
/// tap, and a table view for screen readers and exact values.
class ConsumptionChart extends StatefulWidget {
  const ConsumptionChart({
    super.key,
    required this.report,
    this.buckets,
    this.lowHours,
  });

  final EnergyReport report;

  /// Hours of the lower rate, shaded behind the bars of an hourly chart.
  final Set<int>? lowHours;

  /// Another series over the same range (one device); default: the home.
  final List<EnergyBucket>? buckets;

  @override
  State<ConsumptionChart> createState() => _ConsumptionChartState();
}

class _ConsumptionChartState extends State<ConsumptionChart> {
  int? _selected;
  bool _table = false;

  @override
  void didUpdateWidget(ConsumptionChart old) {
    super.didUpdateWidget(old);
    if (old.report.range != widget.report.range) _selected = null;
  }

  String _slotLabel(String locale, DateTime t, {bool short = false}) =>
      switch (widget.report.range) {
        EnergyRange.today => DateFormat.Hm(locale).format(t),
        EnergyRange.week =>
          short
              ? DateFormat.E(locale).format(t)
              : DateFormat.MMMEd(locale).format(t),
        EnergyRange.month =>
          short
              ? DateFormat.d(locale).format(t)
              : DateFormat.MMMd(locale).format(t),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final buckets = widget.buckets ?? widget.report.buckets;
    final values = [for (final b in buckets) b.consumption];
    final known = values.whereType<double>().toList();
    final maxValue = known.isEmpty ? 0.0 : known.reduce(math.max);
    final peakIndex = known.isEmpty ? null : values.indexOf(maxValue);
    final selected = _selected;

    final caption = selected != null && values[selected] != null
        ? '${_slotLabel(locale, buckets[selected].start)} · ${formatKwh(locale, values[selected]!)}'
        : peakIndex == null
        ? l10n.energyNoData
        : l10n.energyPeak(
            _slotLabel(locale, buckets[peakIndex].start),
            formatKwh(locale, maxValue),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(caption, style: theme.textTheme.bodyMedium)),
            TextButton.icon(
              key: const Key('energyTableToggle'),
              onPressed: () => setState(() => _table = !_table),
              icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
              label: Text(_table ? l10n.energyShowChart : l10n.energyShowTable),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_table)
          _ValueTable(
            rows: [
              for (final b in buckets)
                if (b.consumption != null)
                  (_slotLabel(locale, b.start), b.consumption!),
            ],
          )
        else
          Semantics(
            label: '${l10n.energyConsumptionChart}. $caption',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = buckets.length;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final i =
                        (d.localPosition.dx / constraints.maxWidth * count)
                            .floor()
                            .clamp(0, count - 1);
                    setState(
                      () => _selected = values[i] == null || _selected == i
                          ? null
                          : i,
                    );
                  },
                  child: SizedBox(
                    height: 180,
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 180),
                      painter: _BarsPainter(
                        shaded: [
                          for (final b in buckets)
                            widget.report.range == EnergyRange.today &&
                                (widget.lowHours?.contains(b.start.hour) ??
                                    false),
                        ],
                        shade: theme.colorScheme.secondaryContainer,
                        values: values,
                        maxValue: maxValue,
                        selected: selected,
                        bar: theme.colorScheme.primary,
                        axis: theme.colorScheme.outlineVariant,
                        surface: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (!_table) ...[
          const SizedBox(height: 4),
          _AxisLabels(
            labels: [
              for (final b in buckets) _slotLabel(locale, b.start, short: true),
            ],
          ),
          if (widget.report.range == EnergyRange.today &&
              (widget.lowHours?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Row(
              key: const Key('energyLowLegend'),
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.energyLowLegend,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.shaded,
    required this.shade,
    required this.values,
    required this.maxValue,
    required this.selected,
    required this.bar,
    required this.axis,
    required this.surface,
  });

  /// Slots drawn on a background band (low-rate hours).
  final List<bool> shaded;
  final Color shade;
  final List<double?> values;
  final double maxValue;
  final int? selected;
  final Color bar;
  final Color axis;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 1;
    final band = Paint()..color = shade;
    final slotWidth = size.width / values.length;
    for (var i = 0; i < shaded.length; i++) {
      if (!shaded[i]) continue;
      canvas.drawRect(
        Rect.fromLTWH(i * slotWidth, 0, slotWidth + 0.5, baseline),
        band,
      );
    }
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = axis,
    );
    if (maxValue <= 0) return;

    final slot = size.width / values.length;
    const gap = 2.0; // surface gap between adjacent bars
    final width = math.max(1.0, math.min(slot - gap, 18.0));
    final fill = Paint()..color = bar;
    final dimmed = Paint()..color = bar.withValues(alpha: 0.4);

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null || v <= 0) continue;
      final h = (v / maxValue) * (baseline - 4);
      final left = i * slot + (slot - width) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, baseline - h, width, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, selected == null || selected == i ? fill : dimmed);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.maxValue != maxValue ||
      old.selected != selected ||
      old.bar != bar ||
      !listEquals(old.shaded, shaded);
}

/// A few evenly spaced labels (first, quarters, last) – never one per bar.
const double _labelWidth = 56;

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final n = labels.length;
    final picks = {
      0,
      n ~/ 4,
      n ~/ 2,
      3 * n ~/ 4,
      n - 1,
    }.where((i) => i >= 0 && i < n).toList()..sort();
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: 16,
          child: Stack(
            children: [
              for (final i in picks)
                // Centred under its bar, but kept inside the chart so the
                // first and last labels are not cut off.
                Positioned(
                  left: ((i + 0.5) / n * c.maxWidth - _labelWidth / 2).clamp(
                    0.0,
                    math.max(0.0, c.maxWidth - _labelWidth),
                  ),
                  width: _labelWidth,
                  child: Text(
                    labels[i],
                    style: style,
                    textAlign: i == 0
                        ? TextAlign.start
                        : i == n - 1
                        ? TextAlign.end
                        : TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueTable extends StatelessWidget {
  const _ValueTable({required this.rows});

  final List<(String, double)> rows;

  @override
  Widget build(BuildContext context) {
    final locale = context.l10n.localeName;
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Text(formatKwh(locale, value)),
              ],
            ),
          ),
      ],
    );
  }
}
