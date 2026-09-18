import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import 'picker_sheet.dart';
import 'trace_sheet.dart';

/// Local midnight of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", "Wednesday", then "Wed, Sep 9" — how a day is named
/// wherever the user picks or reads one. The year appears only when it is not
/// this one.
String dayLabel(DateTime day, DateTime today) {
  final d = dateOnly(day);
  final t = dateOnly(today);
  final back = DateTime.utc(t.year, t.month, t.day)
      .difference(DateTime.utc(d.year, d.month, d.day))
      .inDays;
  if (back == 0) return 'Today';
  if (back == 1) return 'Yesterday';
  if (back > 1 && back < 7) return DateFormat('EEEE').format(d);
  return DateFormat(d.year == t.year ? 'EEE, MMM d' : 'EEE, MMM d, yyyy')
      .format(d);
}

/// Picks a day, today or earlier.
///
/// The last week is one tap, because that is where nearly every late entry
/// belongs. Anything older goes through the calendar. There is no future: TRACE
/// records what was done.
Future<DateTime?> showDayPicker(
  BuildContext context, {
  required DateTime selected,
  required DateTime today,
  String title = 'Day',
}) async {
  final t = dateOnly(today);
  final s = dateOnly(selected);
  final recent = [for (var i = 0; i < 7; i++) DateTime(t.year, t.month, t.day - i)];

  // A record, so "Earlier…" is a distinct answer from dismissing the sheet.
  final picked = await showTraceSheet<({DateTime? day})>(
    context: context,
    builder: (context) => PickerSheet(
      title: title,
      children: [
        for (final day in recent)
          PickerRow(
            label: dayLabel(day, t),
            selected: day == s,
            onTap: () => Navigator.of(context).pop((day: day)),
          ),
        PickerRow(
          label: 'Earlier…',
          selected: s.isBefore(recent.last),
          onTap: () => Navigator.of(context).pop((day: null)),
        ),
      ],
    ),
  );

  if (picked == null) return null;
  if (picked.day != null) return picked.day;
  if (!context.mounted) return null;

  final c = context.traceColors;
  final date = await showDatePicker(
    context: context,
    initialDate: s.isAfter(t) ? t : s,
    firstDate: DateTime(2000),
    lastDate: t,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: c.navy,
              surface: c.bg,
            ),
      ),
      child: child!,
    ),
  );
  return date == null ? null : dateOnly(date);
}
