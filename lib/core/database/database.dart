import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/conflict.dart' show SyncRow;
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

  Stream<List<Note>> watchNotesForBook(String bookId) {
    return (select(notes)
          ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // ── Cross-cutting reads ───────────────────────────────────────────────────

  /// Sessions belonging to one project, newest first.
  Stream<List<Entry>> watchEntriesForProject(String projectId) {
    return (select(entries)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Stream<List<Entry>> watchEntriesForBook(String bookId) {
    return (select(entries)
          ..where((t) => t.bookId.equals(bookId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Every live entry between two ISO day keys, inclusive. Drives Insights.
  Stream<List<Entry>> watchEntriesBetween(String fromDate, String toDate) {
    return (select(entries)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(fromDate) &
              t.date.isSmallerOrEqualValue(toDate) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  // ── Sync bookkeeping ──────────────────────────────────────────────────────
  //
  // These deliberately do *not* filter `deletedAt`: a tombstone is exactly what
  // has to reach the server, and a delete that cannot propagate is a delete
  // that resurrects on the next pull.

  Future<List<Entry>> dirtyEntries() =>
      (select(entries)..where((t) => t.dirty.equals(true))).get();

  Future<List<Project>> dirtyProjects() =>
      (select(projects)..where((t) => t.dirty.equals(true))).get();

  Future<List<Book>> dirtyBooks() =>
      (select(books)..where((t) => t.dirty.equals(true))).get();

  Future<List<Note>> dirtyNotes() =>
      (select(notes)..where((t) => t.dirty.equals(true))).get();

  Future<void> markEntriesClean(List<String> ids) =>
      (update(entries)..where((t) => t.id.isIn(ids))).write(
        EntriesCompanion(
          dirty: const Value(false),
          syncedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markProjectsClean(List<String> ids) =>
      (update(projects)..where((t) => t.id.isIn(ids))).write(
        ProjectsCompanion(
          dirty: const Value(false),
          syncedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markBooksClean(List<String> ids) =>
      (update(books)..where((t) => t.id.isIn(ids))).write(
        BooksCompanion(
          dirty: const Value(false),
          syncedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markNotesClean(List<String> ids) =>
      (update(notes)..where((t) => t.id.isIn(ids))).write(
        NotesCompanion(
          dirty: const Value(false),
          syncedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<SyncRow?> entrySyncRow(String id) async {
    final row =
        await (select(entries)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : SyncRow(id: row.id, updatedAt: row.updatedAt, dirty: row.dirty);
  }

  Future<SyncRow?> projectSyncRow(String id) async {
    final row = await (select(projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null
        ? null
        : SyncRow(id: row.id, updatedAt: row.updatedAt, dirty: row.dirty);
  }

  Future<SyncRow?> bookSyncRow(String id) async {
    final row =
        await (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : SyncRow(id: row.id, updatedAt: row.updatedAt, dirty: row.dirty);
  }

  Future<SyncRow?> noteSyncRow(String id) async {
    final row =
        await (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : SyncRow(id: row.id, updatedAt: row.updatedAt, dirty: row.dirty);
  }

  Future<SyncState?> syncState() =>
      (select(syncStates)..where((t) => t.id.equals(1))).getSingleOrNull();

  Stream<SyncState?> watchSyncState() =>
      (select(syncStates)..where((t) => t.id.equals(1))).watchSingleOrNull();

  /// Merges into the single sync-state row.
  ///
  /// [error] is passed explicitly as null to clear a previous failure, which is
  /// why it uses [clearError] rather than treating null as "leave alone".
  Future<void> updateSyncState({
    DateTime? cursor,
    DateTime? lastPushAt,
    String? error,
    bool clearError = false,
  }) {
    return into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion(
        id: const Value(1),
        lastPullCursor:
            cursor == null ? const Value.absent() : Value(cursor),
        lastPushAt:
            lastPushAt == null ? const Value.absent() : Value(lastPushAt),
        lastError: (error == null && !clearError)
            ? const Value.absent()
            : Value(error),
      ),
    );
  }
}
