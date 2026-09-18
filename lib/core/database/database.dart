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
  tables: [Entries, Projects, Books, Notes, Proofs, SyncStates, SyncCursors],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // The pull cursor moved from one client timestamp to a server
            // sequence per table. The old cursor cannot be translated, so it is
            // dropped and the next sync pulls everything once — which also
            // recovers any rows the old cursor had skipped.
            await m.alterTable(TableMigration(syncStates));
            await m.createTable(syncCursors);
          }
          if (from < 3) {
            // Books stopped storing current_page; it is derived from sessions.
            await m.alterTable(TableMigration(books));
          }
        },
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

  /// Writes a whole row. The companion must carry every required column —
  /// drift validates an upsert as an insert, even when the row already exists.
  Future<void> upsertEntry(EntriesCompanion entry) =>
      into(entries).insertOnConflictUpdate(entry);

  /// Writes only the fields present on [entry] to an existing row. Edits go
  /// through here, not [upsertEntry], which rejects a partial companion.
  Future<void> updateEntry(EntriesCompanion entry) =>
      (update(entries)..where((t) => t.id.equals(entry.id.value))).write(entry);

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

  Future<void> updateProject(ProjectsCompanion project) =>
      (update(projects)..where((t) => t.id.equals(project.id.value)))
          .write(project);

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

  Future<void> updateBook(BooksCompanion book) =>
      (update(books)..where((t) => t.id.equals(book.id.value))).write(book);

  static const _pagesReadSql = 'SELECT book_id, CAST(TOTAL(quantity) AS INTEGER)'
      ' AS pages FROM entries WHERE deleted_at IS NULL AND book_id IS NOT NULL'
      " AND quantity_unit = 'pages'";

  /// Pages logged per book, from its live sessions. The bookmark is derived
  /// from this rather than stored, so it cannot disagree with the sessions.
  Stream<Map<String, int>> watchPagesRead() {
    return customSelect(
      '$_pagesReadSql GROUP BY book_id',
      readsFrom: {entries},
    ).watch().map((rows) => {
          for (final r in rows) r.read<String>('book_id'): r.read<int>('pages'),
        });
  }

  Future<int> pagesRead(String bookId) async {
    final row = await customSelect(
      '$_pagesReadSql AND book_id = ?',
      variables: [Variable.withString(bookId)],
      readsFrom: {entries},
    ).getSingleOrNull();
    return row?.readNullable<int>('pages') ?? 0;
  }

  /// Marks a book finished once its sessions reach the last page.
  ///
  /// Called after any write that can add pages, so a book finishes the same
  /// way whether it was logged from Reading or typed into Quick Add. Only ever
  /// moves forward: deleting a session does not un-finish a book, because
  /// the status is the user's to change, not the arithmetic's.
  Future<void> settleBookStatus(String bookId) async {
    final book = await (select(books)..where((t) => t.id.equals(bookId)))
        .getSingleOrNull();
    if (book == null || book.totalPages == null) return;
    if (book.status == 'finished' || book.status == 'abandoned') return;
    if (await pagesRead(bookId) < book.totalPages!) return;

    final now = DateTime.now().toUtc();
    await updateBook(BooksCompanion(
      id: Value(bookId),
      status: const Value('finished'),
      finishedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
  }

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

  Future<void> updateNote(NotesCompanion note) =>
      (update(notes)..where((t) => t.id.equals(note.id.value))).write(note);

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

  // ── Export and erasure ────────────────────────────────────────────────────

  /// Every live row, for the archive. Tombstones are left out: an export is the
  /// record the user kept, not the record they threw away.
  Future<List<Entry>> allEntries() =>
      (select(entries)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.date),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .get();

  Future<List<Note>> allNotes() =>
      (select(notes)..where((t) => t.deletedAt.isNull())).get();

  /// Tombstones every live row and marks it dirty, so the deletion propagates
  /// on the next sync instead of being undone by the next pull.
  ///
  /// Used only when a session exists. Without one there is nowhere for a
  /// tombstone to travel, and [eraseEverything] is the honest operation.
  Future<void> tombstoneEverything() async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(entries)..where((t) => t.deletedAt.isNull())).write(
        EntriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (update(projects)..where((t) => t.deletedAt.isNull())).write(
        ProjectsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (update(books)..where((t) => t.deletedAt.isNull())).write(
        BooksCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (update(notes)..where((t) => t.deletedAt.isNull())).write(
        NotesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
      await (update(proofs)..where((t) => t.deletedAt.isNull())).write(
        ProofsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    });
  }

  /// The only hard DELETE in the app.
  ///
  /// Everywhere else a delete is a tombstone, because a delete that cannot
  /// propagate resurrects. This is the deliberate exception: when the user asks
  /// for their data to be gone, leaving it on disk under a `deleted_at` flag
  /// would not be deletion. The sync cursor goes too, so a later sign-in pulls
  /// from scratch rather than trusting a cursor for rows that no longer exist.
  Future<void> eraseEverything() async {
    await transaction(() async {
      await delete(proofs).go();
      await delete(notes).go();
      await delete(entries).go();
      await delete(books).go();
      await delete(projects).go();
      await delete(syncStates).go();
      await delete(syncCursors).go();
    });
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

  /// Whether any row is waiting to be pushed. Re-emits on every write to the
  /// synced tables, which is what lets auto-sync follow the user's edits
  /// without the repositories knowing sync exists.
  Stream<bool> watchHasDirtyRows() {
    return customSelect(
      'SELECT EXISTS (SELECT 1 FROM entries WHERE dirty = 1)'
      ' OR EXISTS (SELECT 1 FROM projects WHERE dirty = 1)'
      ' OR EXISTS (SELECT 1 FROM books WHERE dirty = 1)'
      ' OR EXISTS (SELECT 1 FROM notes WHERE dirty = 1) AS dirty',
      readsFrom: {entries, projects, books, notes},
    ).watchSingle().map((row) => row.read<bool>('dirty'));
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
    DateTime? lastPushAt,
    String? error,
    bool clearError = false,
  }) {
    return into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion(
        id: const Value(1),
        lastPushAt:
            lastPushAt == null ? const Value.absent() : Value(lastPushAt),
        lastError: (error == null && !clearError)
            ? const Value.absent()
            : Value(error),
      ),
    );
  }

  /// The highest `server_seq` pulled from [table], or null before the first
  /// pull.
  Future<int?> pullCursor(String table) async {
    final row = await (select(syncCursors)..where((t) => t.name.equals(table)))
        .getSingleOrNull();
    return row?.seq;
  }

  Future<void> setPullCursor(String table, int seq) =>
      into(syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(name: table, seq: seq),
      );
}
