import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/parser/entry_parser.dart';
import 'package:trace/features/entries/entry_repository.dart';
import 'package:trace/features/notes/note_repository.dart';
import 'package:trace/features/projects/project_repository.dart';
import 'package:trace/features/reading/book_repository.dart';
import 'package:trace/shared/models/category.dart';

/// Edits write only the fields that changed. They must never be validated as
/// inserts, or every partial write fails for want of `title` and `createdAt`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('an entry edit keeps the fields it does not touch', () async {
    final repo = EntryRepository(db);
    final id = await repo.createFromParsed(const ParsedEntry(
      raw: 'coded for 2 hours on TRACE',
      category: Category.build,
      title: 'TRACE',
      duration: Duration(hours: 2),
      matchedCategory: true,
    ));

    await repo.update(id: id, description: 'Finally figured it out.');

    final row = (await repo.find(id))!;
    expect(row.description, 'Finally figured it out.');
    expect(row.title, 'TRACE');
    expect(row.durationSecs, 7200);
    expect(row.dirty, isTrue);
  });

  test('logging reading moves the bookmark and records a session', () async {
    final repo = BookRepository(db);
    final id = await repo.create(title: 'Atomic Habits', totalPages: 300);
    final book = (await db.allBooks()).single;

    await repo.logSession(book: book, pagesRead: 27, thought: 'Small wins.');
    await repo.update(id: id, author: 'James Clear');

    final updated = (await db.allBooks()).single;
    expect(updated.currentPage, 27);
    expect(updated.author, 'James Clear');
    expect(updated.title, 'Atomic Habits');
    expect((await db.allEntries()).single.quantity, 27);
  });

  test('a project edit keeps its name', () async {
    final repo = ProjectRepository(db);
    final id = await repo.create(name: 'PDS Express');

    await repo.update(id: id, status: ProjectStatus.paused);

    final project = (await db.allProjects()).single;
    expect(project.status, 'paused');
    expect(project.name, 'PDS Express');
  });

  test('rewriting the one line replaces it', () async {
    final repo = NoteRepository(db);
    await repo.setOneLine('2026-09-14', 'First draft.');
    await repo.setOneLine('2026-09-14', 'Second thought.');

    expect((await db.allNotes()).single.body, 'Second thought.');
  });
}
