import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/features/search/search_providers.dart';

/// Personal search: every word must appear, in any field an entry is known by.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final t = DateTime.utc(2026, 9, 1);
    await db.upsertProject(ProjectsCompanion.insert(
      id: 'p1',
      name: 'PDS Express',
      createdAt: t,
      updatedAt: t,
    ));
    await db.upsertBook(BooksCompanion.insert(
      id: 'b1',
      title: 'Designing Data-Intensive Applications',
      createdAt: t,
      updatedAt: t,
    ));
    Future<void> entry(String id, String date, String category, String title,
            {String? note, String? project, String? book}) =>
        db.upsertEntry(EntriesCompanion.insert(
          id: id,
          category: category,
          title: title,
          date: date,
          description: Value(note),
          projectId: Value(project),
          bookId: Value(book),
          createdAt: t,
          updatedAt: t,
        ));
    await entry('e1', '2026-03-03', 'explore', 'Cloudflare Durable Objects');
    await entry('e2', '2026-06-20', 'explore', 'SQLite in the edge',
        note: 'Durable Objects again, with storage');
    await entry('e3', '2026-09-10', 'build', 'Routing fixes', project: 'p1');
    await entry('e4', '2026-09-11', 'read', 'Chapter 5', book: 'b1');
    await entry('e5', '2026-09-12', 'life', '100% of the walk');
  });

  tearDown(() => db.close());

  Future<List<String>> ids(String query) async =>
      [for (final e in await db.watchEntriesMatching(searchWords(query)).first) e.id];

  test('finds a phrase in titles and notes, newest first', () async {
    expect(await ids('durable objects'), ['e2', 'e1']);
  });

  test('ignores case', () async {
    expect(await ids('DURABLE'), ['e2', 'e1']);
  });

  test('every word has to appear', () async {
    expect(await ids('durable storage'), ['e2']);
  });

  test('finds an entry by the project or book it belongs to', () async {
    expect(await ids('express'), ['e3']);
    expect(await ids('data-intensive'), ['e4']);
  });

  test('a percent sign is a character, not a wildcard', () async {
    expect(await ids('100%'), ['e5']);
    expect(await ids('%'), ['e5']);
  });

  test('leaves deleted entries out', () async {
    await db.softDeleteEntry('e1');
    expect(await ids('durable'), ['e2']);
  });

  test('answers when: first day, latest day, how many', () async {
    final span = await db.watchMatchSpan(searchWords('durable')).first;
    expect(span.first, '2026-03-03');
    expect(span.last, '2026-06-20');
    expect(span.count, 2);
  });

  test('searches one-lines and reading thoughts too', () async {
    final t = DateTime.utc(2026, 9, 12);
    await db.upsertNote(NotesCompanion.insert(
      id: 'n1',
      body: 'Finally understood Durable Objects.',
      kind: const Value('one_line'),
      date: const Value('2026-09-12'),
      createdAt: t,
      updatedAt: t,
    ));

    final notes = await db.watchNotesMatching(searchWords('durable')).first;
    expect(notes.single.id, 'n1');
  });

  test('splits a query into words, ignoring spacing', () {
    expect(searchWords('  durable   objects '), ['durable', 'objects']);
    expect(searchWords('   '), isEmpty);
  });
}
