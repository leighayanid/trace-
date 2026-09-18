import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';

/// The one hard-delete path in the app, and the tombstone path that has to run
/// before it when a server is involved.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  final t0 = DateTime.utc(2026, 9, 10, 12, 0);

  Future<void> seed() async {
    await db.upsertEntry(EntriesCompanion.insert(
      id: 'e1',
      category: 'build',
      title: 'PDS Express',
      date: '2026-09-10',
      createdAt: t0,
      updatedAt: t0,
      dirty: const Value(false),
    ));
    await db.upsertProject(ProjectsCompanion.insert(
      id: 'p1',
      name: 'PDS Express',
      createdAt: t0,
      updatedAt: t0,
      dirty: const Value(false),
    ));
    await db.upsertBook(BooksCompanion.insert(
      id: 'b1',
      title: 'The Design of Everyday Things',
      createdAt: t0,
      updatedAt: t0,
      dirty: const Value(false),
    ));
    await db.upsertNote(NotesCompanion.insert(
      id: 'n1',
      body: 'Figured out the shape of it.',
      createdAt: t0,
      updatedAt: t0,
      dirty: const Value(false),
    ));
    await db.updateSyncState(lastPushAt: t0);
    await db.setPullCursor('entries', 42);
  }

  group('allEntries', () {
    test('leaves tombstones out of the archive', () async {
      await seed();
      await db.upsertEntry(EntriesCompanion.insert(
        id: 'e2',
        category: 'life',
        title: 'Walk',
        date: '2026-09-10',
        createdAt: t0,
        updatedAt: t0,
      ));
      await db.softDeleteEntry('e2');

      final rows = await db.allEntries();
      expect(rows.map((e) => e.id), ['e1']);
    });
  });

  group('tombstoneEverything', () {
    test('marks every live row deleted and dirty so the delete can travel',
        () async {
      await seed();
      await db.tombstoneEverything();

      // Dirty is what the push reads; deleted_at is what the server records.
      final entries = await db.dirtyEntries();
      expect(entries.single.deletedAt, isNotNull);
      expect((await db.dirtyProjects()).single.deletedAt, isNotNull);
      expect((await db.dirtyBooks()).single.deletedAt, isNotNull);
      expect((await db.dirtyNotes()).single.deletedAt, isNotNull);
    });

    test('hides everything from the reading side immediately', () async {
      await seed();
      await db.tombstoneEverything();

      expect(await db.allEntries(), isEmpty);
      expect(await db.allProjects(), isEmpty);
      expect(await db.allBooks(), isEmpty);
      expect(await db.allNotes(), isEmpty);
    });

    test('does not resurrect a row that was already deleted', () async {
      await seed();
      await db.softDeleteEntry('e1');
      final before = (await db.findEntry('e1'))!.deletedAt;

      await db.tombstoneEverything();

      expect((await db.findEntry('e1'))!.deletedAt, before);
    });
  });

  group('eraseEverything', () {
    test('removes the rows rather than flagging them', () async {
      await seed();
      await db.eraseEverything();

      // Nothing left even on the unfiltered reads the sync push uses — a
      // tombstone here would mean the data is still on disk.
      expect(await db.dirtyEntries(), isEmpty);
      expect(await db.dirtyProjects(), isEmpty);
      expect(await db.dirtyBooks(), isEmpty);
      expect(await db.dirtyNotes(), isEmpty);
      expect(await db.findEntry('e1'), isNull);
    });

    test('clears the sync cursor so a later sign-in pulls from scratch',
        () async {
      await seed();
      expect(await db.syncState(), isNotNull);

      await db.eraseEverything();

      expect(await db.syncState(), isNull);
      expect(await db.pullCursor('entries'), isNull);
    });

    test('erases tombstones too, not only live rows', () async {
      await seed();
      await db.tombstoneEverything();
      await db.eraseEverything();

      expect(await db.findEntry('e1'), isNull);
      expect(await db.dirtyEntries(), isEmpty);
    });

    test('is safe to run on an empty database', () async {
      await db.eraseEverything();
      expect(await db.allEntries(), isEmpty);
    });
  });
}
