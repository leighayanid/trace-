import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../shared/models/category.dart';
import '../entries/entry_providers.dart';

enum InsightsRange { month, year }

class InsightsRangeNotifier extends Notifier<InsightsRange> {
  @override
  InsightsRange build() => InsightsRange.month;

  void select(InsightsRange r) => state = r;
}

final insightsRangeProvider =
    NotifierProvider<InsightsRangeNotifier, InsightsRange>(
        InsightsRangeNotifier.new);

/// Everything Insights needs, computed once from one query.
class InsightsData {
  const InsightsData({
    required this.from,
    required this.to,
    required this.dayCount,
    required this.presenceByCategory,
    required this.secondsByCategory,
    required this.totalSeconds,
    required this.totalPages,
    required this.projectCount,
    required this.bookCount,
    required this.exploreTopics,
  });

  final DateTime from;
  final DateTime to;
  final int dayCount;

  /// One bool per day in range, per category.
  final Map<Category, List<bool>> presenceByCategory;
  final Map<Category, int> secondsByCategory;
  final int totalSeconds;
  final int totalPages;
  final int projectCount;
  final int bookCount;
  final int exploreTopics;

  /// Share of tracked time, 0–1. Zero when nothing is tracked, rather than NaN.
  double share(Category c) =>
      totalSeconds == 0 ? 0 : (secondsByCategory[c] ?? 0) / totalSeconds;
}

final insightsProvider = StreamProvider<InsightsData>((ref) {
  final range = ref.watch(insightsRangeProvider);
  final db = ref.watch(databaseProvider);
  // Recomputes when the day turns, so the month and year roll over too.
  ref.watch(currentDayProvider);
  final now = DateTime.now();
  final fmt = DateFormat('yyyy-MM-dd');

  final (DateTime from, DateTime to) = switch (range) {
    InsightsRange.month => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1, 0),
      ),
    InsightsRange.year => (DateTime(now.year), DateTime(now.year, 12, 31)),
  };

  final dayCount = to.difference(from).inDays + 1;

  return db
      .watchEntriesBetween(fmt.format(from), fmt.format(to))
      .map((rows) => _fold(rows, from, to, dayCount));
});

InsightsData _fold(
  List<Entry> rows,
  DateTime from,
  DateTime to,
  int dayCount,
) {
  final presence = {
    for (final c in Category.values) c: List<bool>.filled(dayCount, false),
  };
  final seconds = {for (final c in Category.values) c: 0};

  var totalPages = 0;
  final projects = <String>{};
  final books = <String>{};
  final topics = <String>{};

  for (final e in rows) {
    final cat = Category.tryParse(e.category);
    if (cat == null) continue;

    final index = DateTime.parse(e.date).difference(from).inDays;
    if (index >= 0 && index < dayCount) presence[cat]![index] = true;

    seconds[cat] = seconds[cat]! + (e.durationSecs ?? 0);

    if (e.quantityUnit == 'pages') totalPages += (e.quantity ?? 0).round();
    if (e.projectId != null) projects.add(e.projectId!);
    if (e.bookId != null) books.add(e.bookId!);
    if (cat == Category.explore) topics.add(e.title.toLowerCase());
  }

  return InsightsData(
    from: from,
    to: to,
    dayCount: dayCount,
    presenceByCategory: presence,
    secondsByCategory: seconds,
    totalSeconds: seconds.values.fold(0, (a, b) => a + b),
    totalPages: totalPages,
    projectCount: projects.length,
    bookCount: books.length,
    exploreTopics: topics.length,
  );
}
