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
  int get schemaVersion => 4;

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
          if (from < 4) {
            // Rabbit holes and quote pages. New nullable columns only.
            await m.addColumn(entries, entries.parentId);
            await m.addColumn(notes, notes.page);
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

  /// Clears an entry's tombstone.
  Future<void> restoreEntry(String id) {
    final now = DateTime.now().toUtc();
    return (update(entries)..where((t) => t.id.equals(id))).write(
      EntriesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

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

  Stream<Entry?> watchEntry(String id) =>
      (select(entries)..where((t) => t.id.equals(id))).watchSingleOrNull();

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

  // ── Search ────────────────────────────────────────────────────────────────
  //
  // Plain LIKE rather than an FTS index: a personal record is a few thousand
  // rows, which LIKE reads in milliseconds, and it needs no second copy of the
  // text to keep in step. Each word must appear somewhere; case is ignored.

  /// `%word%`, with LIKE's own wildcards in [word] taken literally.
  static String _containing(String word) =>
      '%${word.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';

  /// Every one of [words] in the entry's title or note, or in the name of its
  /// project or book. [query] must join projects and books.
  void _whereEntryMatches(JoinedSelectStatement query, List<String> words) {
    for (final word in words) {
      final pattern = _containing(word);
      query.where(entries.title.like(pattern, escapeChar: r'\') |
          entries.description.like(pattern, escapeChar: r'\') |
          projects.name.like(pattern, escapeChar: r'\') |
          books.title.like(pattern, escapeChar: r'\'));
    }
  }

  /// Live entries in which every one of [words] appears — in the title, the
  /// note, or the name of the project or book it belongs to. Newest first.
  Stream<List<Entry>> watchEntriesMatching(List<String> words,
      {int limit = 200}) {
    final query = select(entries).join([
      leftOuterJoin(projects, projects.id.equalsExp(entries.projectId)),
      leftOuterJoin(books, books.id.equalsExp(entries.bookId)),
    ])
      ..where(entries.deletedAt.isNull());
    _whereEntryMatches(query, words);
    query
      ..orderBy([
        OrderingTerm.desc(entries.date),
        OrderingTerm.desc(entries.createdAt),
      ])
      ..limit(limit);
    return query.watch().map(
          (rows) => [for (final r in rows) r.readTable(entries)],
        );
  }

  /// Live notes — one-lines, thoughts, quotes — containing every one of
  /// [words]. Newest first.
  Stream<List<Note>> watchNotesMatching(List<String> words, {int limit = 100}) {
    final query = select(notes)..where((t) => t.deletedAt.isNull());
    for (final word in words) {
      final pattern = _containing(word);
      query.where((t) => t.body.like(pattern, escapeChar: r'\'));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    return query.watch();
  }

  /// The first and latest day any entry matched, and how many did — the
  /// answer to "when did I first…?", counted over everything rather than the
  /// page of results shown.
  Stream<({String? first, String? last, int count})> watchMatchSpan(
      List<String> words) {
    final first = entries.date.min();
    final last = entries.date.max();
    final count = entries.id.count();
    final query = selectOnly(entries).join([
      leftOuterJoin(projects, projects.id.equalsExp(entries.projectId),
          useColumns: false),
      leftOuterJoin(books, books.id.equalsExp(entries.bookId),
          useColumns: false),
    ])
      ..addColumns([first, last, count])
      ..where(entries.deletedAt.isNull());
    _whereEntryMatches(query, words);
    return query.watchSingle().map((r) => (
          first: r.read(first),
          last: r.read(last),
          count: r.read(count) ?? 0,
        ));
  }

  // ── Rabbit holes ──────────────────────────────────────────────────────────

  /// The chain above [id], root first: what it led on from, what that led on
  /// from, and so on. Stops at a deleted entry, and after 50 steps so a
  /// corrupted loop cannot run away.
  Selectable<Entry> _ancestors(String id) => customSelect(
        'WITH RECURSIVE up(id, parent_id, depth) AS ('
        ' SELECT id, parent_id, 0 FROM entries WHERE id = ?1'
        ' UNION ALL'
        ' SELECT e.id, e.parent_id, up.depth + 1 FROM entries e'
        ' JOIN up ON e.id = up.parent_id'
        ' WHERE e.deleted_at IS NULL AND e.id != ?1 AND up.depth < 50'
        ') SELECT entries.* FROM entries JOIN up ON entries.id = up.id'
        ' WHERE up.depth > 0 ORDER BY up.depth DESC',
        variables: [Variable.withString(id)],
        readsFrom: {entries},
      ).map((row) => entries.map(row.data));

  Stream<List<Entry>> watchAncestors(String id) => _ancestors(id).watch();

  Future<List<Entry>> ancestorsOf(String id) => _ancestors(id).get();

  /// What [id] led on to, in the order it happened.
  Stream<List<Entry>> watchChildren(String id) {
    return (select(entries)
          ..where((t) => t.parentId.equals(id) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  /// Recent EXPLORE entries, newest first — the candidates for "led from".
  Future<List<Entry>> recentExplore({String? excluding, int limit = 30}) {
    return (select(entries)
          ..where((t) =>
              t.category.equals('explore') &
              t.deletedAt.isNull() &
              (excluding == null
                  ? const Constant(true)
                  : t.id.equals(excluding).not()))
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(limit))
        .get();
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
