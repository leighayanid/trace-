import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';

/// The month the Timeline is showing, normalised to its first day.
class VisibleMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() => state = DateTime(state.year, state.month + 1);

  /// True when [state] is the current calendar month — used to stop the user
  /// paging into empty future months.
  bool get isCurrent {
    final now = DateTime.now();
    return state.year == now.year && state.month == now.month;
  }
}

final visibleMonthProvider =
    NotifierProvider<VisibleMonth, DateTime>(VisibleMonth.new);

/// Entries for the visible month, grouped by day, newest day first.
final monthTimelineProvider = StreamProvider<List<DayGroup>>((ref) {
  final month = ref.watch(visibleMonthProvider);
  final fmt = DateFormat('yyyy-MM-dd');

  final from = fmt.format(DateTime(month.year, month.month));
  // Day 0 of the next month is the last day of this one.
  final to = fmt.format(DateTime(month.year, month.month + 1, 0));

  return ref.watch(databaseProvider).watchEntriesBetween(from, to).map((rows) {
    final byDate = <String, List<Entry>>{};
    for (final e in rows) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) DayGroup(date: k, entries: byDate[k]!)];
  });
});
