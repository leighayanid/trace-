import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/export/import_service.dart';
import 'package:trace/core/export/trace_archive.dart';

/// Import merges an export back in, judging each row by its latest edit.
void main() {
  late AppDatabase source;
  late AppDatabase target;

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  final t0 = DateTime.utc(2026, 9, 10, 12);
  final t1 = DateTime.utc(2026, 9, 12, 12);

  EntriesCompanion entry(String id, String title, DateTime at) =>
      EntriesCompanion.insert(
        id: id,
        category: 'build',
        title: title,
        date: '2026-09-10',
        projectId: const Value('p1'),
        createdAt: t0,
        updatedAt: at,
      );

  Future<void> seed(AppDatabase db) async {
    await db.upsertProject(ProjectsCompanion.insert(
      id: 'p1',
      name: 'TRACE',
      createdAt: t0,
      updatedAt: t0,
    ));
    await db.upsertBook(BooksCompanion.insert(
      id: 'b1',
      title: 'Atomic Habits',
      totalPages: const Value(300),
      createdAt: t0,
      updatedAt: t0,
    ));
    await db.upsertEntry(entry('e1', 'TRACE', t0));
    await db.upsertNote(NotesCompanion.insert(
      id: 'n1',
      body: 'Small wins.',
      bookId: const Value('b1'),
      createdAt: t0,
      updatedAt: t0,
    ));
  }

  Future<String> exportOf(AppDatabase db) async => TraceArchive.encodeJson(
        TraceArchive.build(
          entries: await db.allEntries(),
          projects: await db.allProjects(),
          books: await db.allBooks(),
          notes: await db.allNotes(),
          exportedAt: t1,
        ),
      );

  test('restores a whole export onto an empty device', () async {
    await seed(source);

    final outcome = await ImportService(target).importJson(await exportOf(source));

    expect(outcome.added, 4);
    expect(outcome.updated, 0);
    expect((await target.allEntries()).single.title, 'TRACE');
    expect((await target.allBooks()).single.totalPages, 300);
    expect((await target.allNotes()).single.body, 'Small wins.');
    // Marked for the server, like any other edit.
    expect((await target.dirtyEntries()).single.id, 'e1');
  });

  test('importing the same file twice changes nothing the second time',
      () async {
    await seed(source);
    final file = await exportOf(source);
    await ImportService(target).importJson(file);

    final again = await ImportService(target).importJson(file);

    expect(again.added, 0);
    expect(again.updated, 0);
    expect(again.kept, 4);
  });

  test('the later edit wins, on either side', () async {
    await seed(source);
    await seed(target);
    // The archive has the newer e1; this device has the newer project.
    await source.upsertEntry(entry('e1', 'TRACE — sync', t1));
    await target.updateProject(ProjectsCompanion(
      id: const Value('p1'),
      name: const Value('TRACE app'),
      updatedAt: Value(t1),
    ));

    final outcome = await ImportService(target).importJson(await exportOf(source));

    expect(outcome.updated, 1);
    expect((await target.allEntries()).single.title, 'TRACE — sync');
    expect((await target.allProjects()).single.name, 'TRACE app');
  });

  test('reads a version 1 export, whose books still carry current_page',
      () async {
    await seed(source);
    final archive =
        jsonDecode(await exportOf(source)) as Map<String, dynamic>;
    archive['version'] = 1;
    (archive['books'] as List).cast<Map<String, dynamic>>().single['current_page'] = 214;

    await ImportService(target).importJson(jsonEncode(archive));

    expect((await target.allBooks()).single.title, 'Atomic Habits');
  });

  test('refuses what is not an export, and says why', () async {
    Future<String> messageFor(String text) async {
      try {
        await ImportService(target).importJson(text);
      } on FormatException catch (e) {
        return e.message;
      }
      fail('accepted $text');
    }

    expect(await messageFor('not json'), "That file isn't a TRACE export.");
    expect(await messageFor('{"format": "other"}'),
        "That file isn't a TRACE export.");
    expect(await messageFor('{"format": "trace.archive", "version": 99}'),
        contains('newer version'));
  });

  test('a damaged row imports nothing at all', () async {
    await seed(source);
    final archive =
        jsonDecode(await exportOf(source)) as Map<String, dynamic>;
    // The entry loses its timestamp; the project before it was fine.
    (archive['entries'] as List).cast<Map<String, dynamic>>().single
        .remove('updated_at');

    await expectLater(
      ImportService(target).importJson(jsonEncode(archive)),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', 'That export is damaged.')),
    );
    expect(await target.allProjects(), isEmpty);
  });
}
