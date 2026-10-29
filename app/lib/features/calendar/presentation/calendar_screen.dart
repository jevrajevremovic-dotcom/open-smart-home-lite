import 'package:flutter/material.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/responsive.dart';
import 'calendar_browser.dart';
import 'calendar_widgets.dart';

/// Calendars from Home Assistant: month grid and agenda.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = WindowSize.of(context) != WindowSize.compact;
    final palette = CalendarPalette.of(Theme.of(context));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.calendarTitle)),
      body: wide
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CalendarBrowser(palette: palette),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CalendarBrowser(palette: palette, wide: false),
                ),
              ),
            ),
    );
  }
}
