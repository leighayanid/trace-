import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';

/// Opens databases left behind by older builds and checks the upgrade.
/// A migration that throws here would throw on the phone at launch.
void main() {
  // The tables the upgrades touch, exactly as schema versions 1 and 2 created
  // them. The others did not change and are left out.
  const syncStatesV1 = [
    'CREATE TABLE "sync_states" ('
        '"id" INTEGER NOT NULL DEFAULT 1, '
        '"last_pull_cursor" INTEGER NULL, '
        '"last_push_at" INTEGER NULL, '
        '"last_error" TEXT NULL, '
        'PRIMARY KEY ("id"))',
    'INSERT INTO sync_states VALUES (1, 1789000000, 1789000000, '
        "'No connection')",
  ];

  const booksV2 = [
    'CREATE TABLE "books" ('
        '"id" TEXT NOT NULL, '
        '"created_at" INTEGER NOT NULL, '
        '"updated_at" INTEGER NOT NULL, '
        '"deleted_at" INTEGER NULL, '
        '"dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("dirty" IN (0, 1)), '
        '"synced_at" INTEGER NULL, '
        '"title" TEXT NOT NULL, '
        '"author" TEXT NULL, '
        '"cover_path" TEXT NULL, '
        '"current_page" INTEGER NOT NULL DEFAULT 0, '
        '"total_pages" INTEGER NULL, '
        '"status" TEXT NOT NULL DEFAULT \'reading\', '
        '"started_at" INTEGER NULL, '
        '"finished_at" INTEGER NULL, '
        'PRIMARY KEY ("id"))',
    "INSERT INTO books (id, created_at, updated_at, title, "
        "current_page, total_pages) VALUES "
        "('b1', 1789000000, 1789000000, 'Atomic Habits', 27, 300)",
  ];

  AppDatabase open(int version, List<String> schema) {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      schema.forEach(raw.execute);
      raw.userVersion = version;
    }));
    addTearDown(db.close);
    return db;
  }

  Future<List<String>> columns(AppDatabase db, String table) => db
      .customSelect("SELECT name FROM pragma_table_info('$table')")
      .map((r) => r.read<String>('name'))
      .get();

  test('v1 → v3 swaps the timestamp cursor for per-table cursors', () async {
    // Books did not change between v1 and v2.
    final db = open(1, [...syncStatesV1, ...booksV2]);

    final state = await db.syncState();
    expect(state!.lastPushAt, DateTime.fromMillisecondsSinceEpoch(1789000000000));
    expect(state.lastError, 'No connection');
    expect(await columns(db, 'sync_states'), isNot(contains('last_pull_cursor')));

    // No cursor survives the upgrade, so the first sync pulls everything once —
    // which also recovers rows the old cursor had skipped.
    expect(await db.pullCursor('entries'), isNull);
    await db.setPullCursor('entries', 7);
    expect(await db.pullCursor('entries'), 7);
  });

  test('v2 → v3 drops the stored page and keeps the book', () async {
    final db = open(2, [
      ...booksV2,
      'CREATE TABLE "sync_cursors" ("name" TEXT NOT NULL, '
          '"seq" INTEGER NOT NULL, PRIMARY KEY ("name"))',
      'CREATE TABLE "sync_states" ("id" INTEGER NOT NULL DEFAULT 1, '
          '"last_push_at" INTEGER NULL, "last_error" TEXT NULL, '
          'PRIMARY KEY ("id"))',
    ]);

    expect(await columns(db, 'books'), isNot(contains('current_page')));
    final book = (await db.allBooks()).single;
    expect(book.title, 'Atomic Habits');
    expect(book.totalPages, 300);
  });
}
