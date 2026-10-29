import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/presentation/device_grid.dart' show EmptyHint;
import '../../devices/presentation/device_presentation.dart';
import '../application/weather_providers.dart';
import '../domain/weather.dart';
import 'animated_weather_icon.dart';
import 'weather_labels.dart';

/// Full forecast from the Home Assistant weather entity: now, the next
/// hours (temperature curve) and the next days (temperature ranges).
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(homeWeatherProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.weatherForecastTitle)),
      body: report == null
          ? EmptyHint(
              icon: Icons.cloud_off_outlined,
              text: l10n.weatherNoForecast,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _NowCard(report: report),
                if (report.hourly.isNotEmpty) ...[
                  _Header(l10n.weatherHourly),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: HourlyStrip(
                        hours: report.hourly.take(24).toList(),
                      ),
                    ),
                  ),
                ],
                if (report.daily.isNotEmpty) ...[
                  _Header(l10n.weatherDaily),
                  Card(child: DailyRanges(days: report.daily)),
                ],
                if (report.hourly.isEmpty && report.daily.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: InlineNotice.info(l10n.weatherNoForecast),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l10n.weatherFeelsHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final now = report.now;
    final today = report.daily.isEmpty ? null : report.daily.first;
    String t(double? v) => v == null ? '—' : formatNumber(locale, v, unit: '°');
    final details = [
      if (today != null) '↑ ${t(today.high)}  ↓ ${t(today.low)}',
      if (now.humidity != null)
        '${l10n.summaryHumidity} ${formatNumber(locale, now.humidity!, unit: '%')}',
      if (now.windSpeed != null)
        '${l10n.weatherWind} ${formatNumber(locale, now.windSpeed!, unit: now.windSpeedUnit)}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedWeatherIcon(
                  condition: now.condition,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t(now.temperature),
                      style: theme.textTheme.displayMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              weatherConditionLabel(l10n, now.condition),
              style: theme.textTheme.titleLarge,
            ),
            for (final line in details)
              Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling hours with a temperature curve above them.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip({
    super.key,
    required this.hours,
    this.foreground,
    this.muted,
    this.lineColor,
  });

  final List<HourlyForecast> hours;

  /// Colours for use on glass (kiosk); theme colours otherwise.
  final Color? foreground;
  final Color? muted;
  final Color? lineColor;

  static const _cell = 64.0;
  static const _curve = 66.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurface;
    final dim = muted ?? theme.colorScheme.onSurfaceVariant;
    final temps = [for (final h in hours) h.temperature];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              size: Size(_cell * hours.length, _curve),
              painter: _CurvePainter(
                temps: temps,
                cell: _cell,
                color: lineColor ?? theme.colorScheme.primary,
                labelStyle: theme.textTheme.labelLarge!.copyWith(color: fg),
                locale: locale,
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, h) in hours.indexed)
                Semantics(
                  label:
                      '${DateFormat.Hm(locale).format(h.time)}: '
                      '${weatherConditionLabel(l10n, h.condition)}, '
                      '${h.temperature == null ? '' : formatNumber(locale, h.temperature!, unit: '°')}',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: _cell,
                    child: Column(
                      children: [
                        Icon(weatherIcon(h.condition), color: fg, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          (h.precipitationProbability ?? 0) >= 20
                              ? '${h.precipitationProbability!.round()} %'
                              : '',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF4FA3E0),
                          ),
                        ),
                        Text(
                          i == 0
                              ? l10n.weatherNow
                              : DateFormat.H(locale).format(h.time),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.temps,
    required this.cell,
    required this.color,
    required this.labelStyle,
    required this.locale,
  });

  final List<double?> temps;
  final double cell;
  final Color color;
  final TextStyle labelStyle;
  final String locale;

  @override
  void paint(Canvas canvas, Size size) {
    final known = temps.whereType<double>();
    if (known.isEmpty) return;
    final lo = known.reduce(math.min);
    final hi = known.reduce(math.max);
    const top = 30.0; // room for the labels
    final bottom = size.height - 6;
    double y(double t) => hi == lo
        ? (top + bottom) / 2
        : bottom - (t - lo) / (hi - lo) * (bottom - top);

    final points = [
      for (var i = 0; i < temps.length; i++)
        if (temps[i] != null) Offset(i * cell + cell / 2, y(temps[i]!)),
    ];
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final mid = (p0.dx + p1.dx) / 2;
        path.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < temps.length; i++) {
      final t = temps[i];
      if (t == null) continue;
      final p = Offset(i * cell + cell / 2, y(t));
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: formatNumber(locale, t, unit: '°'),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 4));
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.temps != temps || old.color != color || old.labelStyle != labelStyle;
}

/// Next days: weekday, icon, precipitation, and a low–high bar placed on
/// the week's overall temperature range.
class DailyRanges extends StatelessWidget {
  const DailyRanges({
    super.key,
    required this.days,
    this.foreground,
    this.muted,
    this.track,
  });

  final List<DailyForecast> days;
  final Color? foreground;
  final Color? muted;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurface;
    final dim = muted ?? theme.colorScheme.onSurfaceVariant;
    final lows = days.map((d) => d.low ?? d.high).whereType<double>();
    final highs = days.map((d) => d.high ?? d.low).whereType<double>();
    final min = lows.isEmpty ? 0.0 : lows.reduce(math.min);
    final max = highs.isEmpty ? 1.0 : highs.reduce(math.max);
    String t(double? v) => v == null ? '—' : formatNumber(locale, v, unit: '°');
    final today = DateTime.now();

    return Column(
      children: [
        for (final d in days)
          Semantics(
            label:
                '${DateFormat.EEEE(locale).format(d.date)}: '
                '${weatherConditionLabel(l10n, d.condition)}, ${t(d.high)} / ${t(d.low)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      DateUtils.isSameDay(d.date, today)
                          ? l10n.weatherToday
                          : DateFormat.E(locale).format(d.date),
                      style: theme.textTheme.titleSmall?.copyWith(color: fg),
                    ),
                  ),
                  Icon(weatherIcon(d.condition), color: fg, size: 26),
                  SizedBox(
                    width: 64,
                    child: Text(
                      (d.precipitation ?? 0) > 0
                          ? formatNumber(locale, d.precipitation!, unit: ' mm')
                          : '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4FA3E0),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      t(d.low),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(color: dim),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RangeBar(
                      min: min,
                      max: max,
                      low: d.low ?? d.high,
                      high: d.high ?? d.low,
                      track: track ?? theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      t(d.high),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.min,
    required this.max,
    required this.low,
    required this.high,
    required this.track,
  });

  final double min;
  final double max;
  final double? low;
  final double? high;
  final Color track;

  /// Cool to warm, by temperature (°C).
  static Color _tempColor(double t) => switch (t) {
    < 0 => const Color(0xFF6CB8FF),
    < 10 => const Color(0xFF58C7C2),
    < 20 => const Color(0xFFF2C14E),
    < 28 => const Color(0xFFFF9C5B),
    _ => const Color(0xFFFF6B5B),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final span = max - min == 0 ? 1 : max - min;
      final l = low == null ? 0.0 : (low! - min) / span;
      final h = high == null ? 0.0 : (high! - min) / span;
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(3),
        ),
        child: low == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: EdgeInsets.only(left: c.maxWidth * l),
                  width: math.max(6, c.maxWidth * (h - l)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [_tempColor(low!), _tempColor(high ?? low!)],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
