import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// A day's worth of entries, grouped for the Timeline.
class DayGroup {
  const DayGroup({required this.date, required this.entries});

  /// ISO `yyyy-MM-dd`.
  final String date;
  final List<Entry> entries;

  Duration get total => entries.fold(
        Duration.zero,
        (sum, e) => sum + Duration(seconds: e.durationSecs ?? 0),
      );
}

@DriftDatabase(
  tables: [Entries, Projects, Books, Notes, Proofs, SyncStates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Required for the ON DELETE behaviour of related rows.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _open() =>
      driftDatabase(name: 'trace', native: const DriftNativeOptions());

  // ── Entries ───────────────────────────────────────────────────────────────

  /// Live entries for one day, newest first.
  ///
  /// Every read filters `deletedAt IS NULL`; tombstones exist for sync, not for
  /// display.
  Stream<List<Entry>> watchEntriesForDate(String date) {
    return (select(entries)
          ..where((t) => t.date.equals(date) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Entry>> watchRecentEntries({int limit = 200}) {
    return (select(entries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(limit))
        .watch();
  }

  /// Entries grouped by day, for the Timeline.
  Stream<List<DayGroup>> watchTimeline({int limit = 500}) {
    return watchRecentEntries(limit: limit).map((rows) {
      final byDate = <String, List<Entry>>{};
      for (final e in rows) {
        byDate.putIfAbsent(e.date, () => []).add(e);
      }
      final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
      return [
        for (final k in keys) DayGroup(date: k, entries: byDate[k]!),
      ];
    });
  }

  Future<void> upsertEntry(EntriesCompanion entry) =>
      into(entries).insertOnConflictUpdate(entry);

  /// Tombstones an entry. Never issues a hard DELETE.
  Future<void> softDeleteEntry(String id) {
    final now = DateTime.now().toUtc();
    return (update(entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  Future<Entry?> findEntry(String id) =>
      (select(entries)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ── Projects ──────────────────────────────────────────────────────────────

  Stream<List<Project>> watchProjects() {
    return (select(projects)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Project>> allProjects() =>
      (select(projects)..where((t) => t.deletedAt.isNull())).get();

  Future<void> upsertProject(ProjectsCompanion project) =>
      into(projects).insertOnConflictUpdate(project);

  /// Total tracked time on a project, derived from its entries.
  ///
  /// Never stored on the project row — a duplicated total is a total that goes
  /// stale.
  Stream<Duration> watchProjectTime(String projectId) {
    final sum = entries.durationSecs.sum();
    final query = selectOnly(entries)
      ..addColumns([sum])
      ..where(entries.projectId.equals(projectId) & entries.deletedAt.isNull());
    return query
        .watchSingle()
        .map((row) => Duration(seconds: row.read(sum) ?? 0));
  }

  // ── Books ─────────────────────────────────────────────────────────────────

  Stream<List<Book>> watchBooks() {
    return (select(books)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  Future<List<Book>> allBooks() =>
      (select(books)..where((t) => t.deletedAt.isNull())).get();

  Future<void> upsertBook(BooksCompanion book) =>
      into(books).insertOnConflictUpdate(book);

  // ── Notes ─────────────────────────────────────────────────────────────────

  /// The ONE LINE for a given day, if written.
  Stream<Note?> watchOneLine(String date) {
    return (select(notes)
          ..where((t) =>
              t.date.equals(date) &
              t.kind.equals('one_line') &
              t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsertNote(NotesCompanion note) =>
      into(notes).insertOnConflictUpdate(note);
}
