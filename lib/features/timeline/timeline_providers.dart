import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';

/// Which way the last month change went: -1 back, +1 forward.
///
/// Read by the Timeline so the shared-axis transition travels in the direction
/// of the arrow pressed. Without it, paging back would still slide forward.
class MonthDirection extends Notifier<int> {
  @override
  int build() => 1;

  void set(int value) => state = value;
}

final monthDirectionProvider =
    NotifierProvider<MonthDirection, int>(MonthDirection.new);

/// The month the Timeline is showing, normalised to its first day.
class VisibleMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() {
    ref.read(monthDirectionProvider.notifier).set(-1);
    state = DateTime(state.year, state.month - 1);
  }

  void next() {
    ref.read(monthDirectionProvider.notifier).set(1);
    state = DateTime(state.year, state.month + 1);
  }

  /// Shows the month [day] falls in, arriving from the side it lies on.
  void showMonthOf(DateTime day) {
    final month = DateTime(day.year, day.month);
    if (month == state) return;
    ref.read(monthDirectionProvider.notifier).set(month.isBefore(state) ? -1 : 1);
    state = month;
  }

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
