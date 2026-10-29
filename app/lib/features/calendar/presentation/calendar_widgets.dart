import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../integrations/home_assistant/models/ha_calendar.dart';
import '../application/calendar_providers.dart';

/// Colours for the calendar widgets, from the app theme.
@immutable
class CalendarPalette {
  const CalendarPalette({
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.selected,
  });

  factory CalendarPalette.of(ThemeData theme) => CalendarPalette(
    text: theme.colorScheme.onSurface,
    muted: theme.colorScheme.onSurfaceVariant,
    faint: theme.colorScheme.outline,
    accent: theme.colorScheme.primary,
    onAccent: theme.colorScheme.onPrimary,
    selected: theme.colorScheme.primaryContainer,
  );

  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final Color selected;
}

/// Month grid (Monday first) with arrows, today highlighted, the selected
/// day marked and a dot under days that have events.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onSelect,
    required this.onMonth,
    required this.palette,
    this.scale = 1,
  });

  /// Larger days, labels and title (e.g. a wall tablet across the room).
  final double scale;

  final DateTime month;
  final DateTime selectedDay;
  final List<HaCalendarEvent> events;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonth;
  final CalendarPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final k = scale;
    TextStyle? big(TextStyle? t) =>
        t?.copyWith(fontSize: (t.fontSize ?? 14) * k);
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - 1; // Monday first
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((lead + daysInMonth) / 7).ceil();
    final today = DateUtils.dateOnly(DateTime.now());
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)), // a Monday
    ];

    Widget cell(DateTime day) {
      final inMonth = day.month == month.month;
      final isToday = DateUtils.isSameDay(day, today);
      final isSelected = DateUtils.isSameDay(day, selectedDay);
      final busy = events.any((e) => e.occursOn(day));
      return Semantics(
        button: true,
        selected: isSelected,
        label: DateFormat.yMMMMEEEEd(locale).format(day),
        excludeSemantics: true,
        child: InkResponse(
          key: ValueKey('calDay-${day.month}-${day.day}'),
          onTap: () => onSelect(day),
          radius: 22 * k,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32 * k,
                height: 32 * k,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? palette.accent
                      : isSelected
                      ? palette.selected
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: big(theme.textTheme.bodyLarge)?.copyWith(
                    color: isToday
                        ? palette.onAccent
                        : inMonth
                        ? palette.text
                        : palette.faint,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: 2 * k),
              Container(
                width: 5 * k,
                height: 5 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? palette.muted : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('calPrevMonth'),
              tooltip: l10n.calendarPrevMonth,
              color: palette.accent,
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                toBeginningOfSentenceCase(
                  DateFormat.yMMMM(locale).format(month),
                  locale,
                ),
                key: const Key('calMonthTitle'),
                textAlign: TextAlign.center,
                style: big(theme.textTheme.titleMedium)
                    ?.copyWith(color: palette.text),
              ),
            ),
            IconButton(
              key: const Key('calNextMonth'),
              tooltip: l10n.calendarNextMonth,
              color: palette.accent,
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(
                  w.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: big(theme.textTheme.labelSmall)
                      ?.copyWith(color: palette.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: 42 * k,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: cell(
                      DateTime(month.year, month.month, 1 - lead + r * 7 + c),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Events from [from] on, grouped by day ("Today", "Tomorrow", weekday).
class CalendarAgenda extends ConsumerWidget {
  const CalendarAgenda({
    super.key,
    required this.events,
    required this.from,
    required this.palette,
    this.days = 7,
    this.shrinkWrap = false,
  });

  final List<HaCalendarEvent> events;
  final DateTime from;
  final CalendarPalette palette;
  final int days;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(from);

    String dayTitle(DateTime d) {
      if (DateUtils.isSameDay(d, today)) return l10n.calendarToday;
      if (DateUtils.isSameDay(d, today.add(const Duration(days: 1)))) {
        return l10n.calendarTomorrow;
      }
      return toBeginningOfSentenceCase(
        DateFormat.MMMMEEEEd(locale).format(d),
        locale,
      );
    }

    final groups = <(DateTime, List<HaCalendarEvent>)>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final list = events.where((e) => e.occursOn(d)).toList()
        ..sort(compareEvents);
      // The selected day is always listed; later days only with events.
      if (i == 0 || list.isNotEmpty) groups.add((d, list));
    }

    final children = <Widget>[
      for (final (day, list) in groups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Semantics(
            header: true,
            child: Text(
              dayTitle(day).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.muted,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.calendarNoEvents,
              style: theme.textTheme.bodyMedium?.copyWith(color: palette.faint),
            ),
          ),
        for (final e in list) _EventRow(event: e, day: day, palette: palette),
      ],
    ];
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: children,
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({
    required this.event,
    required this.day,
    required this.palette,
  });

  final HaCalendarEvent event;
  final DateTime day;
  final CalendarPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final theme = Theme.of(context);
    final color = ref.watch(calendarColorProvider(event.calendarId));
    final dayStart = DateUtils.dateOnly(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    // A timed event spanning midnight counts as all-day on the middle days.
    final wholeDay =
        event.allDay ||
        (!event.start.isAfter(dayStart) && !event.end.isBefore(dayEnd));
    final hm = DateFormat.Hm(locale);
    final when = wholeDay
        ? l10n.calendarAllDay
        : '${hm.format(event.start)} – ${hm.format(event.end)}';
    final title = event.summary.isEmpty ? '—' : event.summary;

    return Semantics(
      label:
          '$title, $when${event.location == null ? '' : ', ${event.location}'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.text,
                      ),
                    ),
                    Text(
                      [when, ?event.location].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
