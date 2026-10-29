import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/edge_fade.dart';
import '../../../app/localization/l10n.dart';
import '../application/calendar_providers.dart';
import 'calendar_widgets.dart';

/// Month grid + agenda with its own month/day selection. [wide] puts the
/// agenda left of the grid (tablet, kiosk); otherwise the grid is on top.
class CalendarBrowser extends ConsumerStatefulWidget {
  const CalendarBrowser({
    super.key,
    required this.palette,
    this.wide = true,
    this.fitGrid = false,
    this.header,
    this.gridScale = 1,
    this.agendaDays = 7,
    this.evenSplit = false,
  });

  /// Wide: agenda and month take half each (else ≈ 5:4).
  final bool evenSplit;

  /// How many days the agenda covers.
  final int agendaDays;

  /// Size of the month grid's days and labels (see [MonthGrid.scale]).
  final double gridScale;

  final CalendarPalette palette;
  final bool wide;

  /// Scale the grid down to the available height (kiosk panel).
  final bool fitGrid;

  /// Shown above the agenda (e.g. the panel title).
  final Widget? header;

  @override
  ConsumerState<CalendarBrowser> createState() => _CalendarBrowserState();
}

class _CalendarBrowserState extends ConsumerState<CalendarBrowser> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateUtils.dateOnly(now);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.palette;
    final calendars = ref.watch(calendarsProvider);
    final events = ref.watch(calendarMonthEventsProvider(_month));

    Widget message(String text, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: TextStyle(color: p.muted)),
    );

    // Without calendars (or when they fail) the month grid still shows;
    // the agenda explains why it is empty.
    final noCalendars = calendars.hasValue && calendars.value!.isEmpty;
    final calendarsFailed = calendars.hasError && !calendars.hasValue;

    final list = events.value ?? const [];
    final grid = MonthGrid(
      month: _month,
      selectedDay: _selected,
      events: list,
      palette: p,
      scale: widget.gridScale,
      onMonth: (m) => setState(() => _month = m),
      onSelect: (d) => setState(() {
        _selected = d;
        if (d.month != _month.month || d.year != _month.year) {
          _month = DateTime(d.year, d.month);
        }
      }),
    );
    final agenda = noCalendars
        ? message(l10n.calendarNone, key: const Key('calendarNone'))
        : calendarsFailed || (events.hasError && !events.hasValue)
        ? message(l10n.calendarUnavailable)
        : CalendarAgenda(
            key: const Key('calendarAgenda'),
            events: list,
            from: _selected,
            palette: p,
            days: widget.agendaDays,
            shrinkWrap: !widget.wide,
          );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.wide ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.wide) ?widget.header,
        if (events.isLoading && !events.hasValue)
          LinearProgressIndicator(color: p.accent, minHeight: 2),
        if (widget.wide) Expanded(child: EdgeFade(child: agenda)) else agenda,
      ],
    );

    if (!widget.wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Title, the month, then the agenda.
        children: [?widget.header, grid, const SizedBox(height: 12), left],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: widget.evenSplit ? 1 : 5, child: left),
        const SizedBox(width: 20),
        Expanded(
          flex: widget.evenSplit ? 1 : 4,
          child: widget.fitGrid
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 320 * widget.gridScale, child: grid),
                )
              : SingleChildScrollView(child: grid),
        ),
      ],
    );
  }
}
