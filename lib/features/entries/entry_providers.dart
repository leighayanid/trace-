import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../core/parser/entry_parser.dart';
import 'entry_repository.dart';

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepository(ref.watch(databaseProvider)),
);

/// Today's day key, kept current while the app stays open.
///
/// Read once at launch, it would leave Today showing yesterday — and filing new
/// entries under the right day while showing the wrong one — until a restart.
/// A timer moves it at midnight; since timers do not run while the app is
/// suspended, resuming checks again.
class CurrentDay extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    // A second late, so the check cannot land just before the day turns.
    final timer = Timer(
      midnight.difference(now) + const Duration(seconds: 1),
      _check,
    );
    final lifecycle = AppLifecycleListener(onResume: _check);
    ref.onDispose(() {
      timer.cancel();
      lifecycle.dispose();
    });
    return dayKey(now);
  }

  void _check() {
    if (dayKey(DateTime.now()) != state) ref.invalidateSelf();
  }
}

final currentDayProvider =
    NotifierProvider<CurrentDay, String>(CurrentDay.new);

/// The day Today is showing. Follows [currentDayProvider], so it moves on at
/// midnight along with the clock.
///
/// A [Notifier] rather than the legacy `StateProvider`, which Riverpod 3 moved
/// behind a separate import.
class SelectedDate extends Notifier<String> {
  @override
  String build() => ref.watch(currentDayProvider);

  void select(String date) => state = date;

  void today() => state = ref.read(currentDayProvider);
}

final selectedDateProvider =
    NotifierProvider<SelectedDate, String>(SelectedDate.new);

final todayEntriesProvider = StreamProvider<List<Entry>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(entryRepositoryProvider).watchForDate(date);
});

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(databaseProvider).watchProjects(),
);

final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(databaseProvider).watchBooks(),
);

/// A parser primed with the user's own project and book names, so "worked on
/// PDS Express" resolves to a real row rather than a loose string.
final entryParserProvider = Provider<EntryParser>((ref) {
  final projects = ref.watch(projectsProvider).value ?? const [];
  final books = ref.watch(booksProvider).value ?? const [];
  return EntryParser(
    projects: [for (final p in projects) NamedRef(p.id, p.name)],
    books: [for (final b in books) NamedRef(b.id, b.title)],
  );
});

final oneLineProvider = StreamProvider<Note?>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(databaseProvider).watchOneLine(date);
});

/// Presence: the share of the four categories touched today.
///
/// Chosen because it is explainable in one sentence and cannot be gamed into a
/// score — it measures the *breadth* of a day, not achievement. Four entries in
/// one category read the same as one. Still awaiting confirmation; changing the
/// definition means changing this function and nothing else.
final presenceProvider = Provider<double>((ref) {
  final entries = ref.watch(todayEntriesProvider).value ?? const [];
  if (entries.isEmpty) return 0;
  final touched = entries.map((e) => e.category).toSet().length;
  return touched / 4;
});
