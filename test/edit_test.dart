import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/features/entries/entry_draft.dart';
import 'package:trace/features/entries/entry_repository.dart';
import 'package:trace/features/notes/note_repository.dart';
import 'package:trace/features/projects/project_repository.dart';
import 'package:trace/features/reading/book_repository.dart';
import 'package:trace/shared/models/category.dart';

/// Edits must never be validated as inserts, or every write fails for want of
/// `createdAt`. Entry edits write the whole draft; the others write only the
/// fields they are given.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  EntryDraft build({
    Category category = Category.build,
    String title = 'TRACE',
    String? description,
    Duration? duration = const Duration(hours: 2),
    String? projectId = 'p1',
    String? bookId,
  }) =>
      EntryDraft(
        category: category,
        title: title,
        description: description,
        duration: duration,
        projectId: projectId,
        bookId: bookId,
      );

  test('saving a draft writes what it carries and marks the row dirty',
      () async {
    final repo = EntryRepository(db);
    final id = await repo.create(build());

    await repo.save(id, build(description: 'Finally figured it out.'));

    final row = (await repo.find(id))!;
    expect(row.description, 'Finally figured it out.');
    expect(row.title, 'TRACE');
    expect(row.durationSecs, 7200);
    expect(row.projectId, 'p1');
    expect(row.dirty, isTrue);
  });

  test('saving a draft clears what it leaves empty', () async {
    // Null used to mean "unchanged", so a duration, a project or a note could
    // be added but never taken away.
    final repo = EntryRepository(db);
    final id = await repo.create(build(description: 'A note.'));

    await repo.save(
      id,
      build(duration: null, projectId: null, description: '  '),
    );

    final row = (await repo.find(id))!;
    expect(row.durationSecs, isNull);
    expect(row.projectId, isNull);
    expect(row.description, isNull);
  });

  test('a link the category hides is not saved', () async {
    final repo = EntryRepository(db);
    final id = await repo.create(
      build(category: Category.explore, projectId: 'p1', bookId: 'b1'),
    );

    final row = (await repo.find(id))!;
    expect(row.projectId, isNull);
    expect(row.bookId, isNull);
  });

  test('an entry opens for editing with its note and amount', () async {
    final repo = EntryRepository(db);
    final id = await repo.create(const EntryDraft(
      category: Category.read,
      title: 'Atomic Habits',
      description: 'Small wins.',
      quantity: 27,
      quantityUnit: 'pages',
    ));

    final draft = EntryDraft.fromEntry((await repo.find(id))!);
    expect(draft.description, 'Small wins.');
    expect(draft.quantity, 27);
    expect(draft.quantityUnit, 'pages');
  });

  test('a book edit keeps the fields it does not touch', () async {
    final repo = BookRepository(db);
    final id = await repo.create(title: 'Atomic Habits', totalPages: 300);

    await repo.update(id: id, author: 'James Clear');

    final updated = (await db.allBooks()).single;
    expect(updated.author, 'James Clear');
    expect(updated.title, 'Atomic Habits');
    expect(updated.totalPages, 300);
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
