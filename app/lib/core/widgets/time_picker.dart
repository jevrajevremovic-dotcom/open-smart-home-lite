import 'package:flutter/material.dart';

/// [showTimePicker] that follows the language's clock: where the language
/// writes 24-hour time (Serbian), the picker takes hours 0–23 even when the
/// phone itself is set to 12-hour time. Otherwise the text entry would take
/// only 1–12 and offer no AM/PM, so 22:00 could not be entered.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
}) {
  final format = MaterialLocalizations.of(context).timeOfDayFormat();
  final twentyFour =
      format == TimeOfDayFormat.HH_colon_mm ||
      format == TimeOfDayFormat.HH_dot_mm ||
      format == TimeOfDayFormat.frenchCanadian;
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: helpText,
    builder: twentyFour
        ? (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          )
        : null,
  );
}
