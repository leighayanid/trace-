import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/parser/entry_parser.dart';
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

  test('a draft carries the day the sentence named', () async {
    final repo = EntryRepository(db);
    final today = DateTime(2026, 9, 18);
    final parsed = const EntryParser().parse('walked for 30m yesterday');

    final id = await repo.create(EntryDraft.fromParsed(parsed, today: today));

    expect((await repo.find(id))!.date, '2026-09-17');
  });

  test('without a named day, a draft goes to the day being viewed', () async {
    final parsed = const EntryParser().parse('walked for 30m');
    final draft = EntryDraft.fromParsed(
      parsed,
      today: DateTime(2026, 9, 18),
      day: DateTime(2026, 9, 15),
    );
    expect(draft.date, DateTime(2026, 9, 15));
  });

  test('saving a draft with a day moves the entry; without one keeps it',
      () async {
    final repo = EntryRepository(db);
    final id = await repo.create(build());
    final original = (await repo.find(id))!.date;

    await repo.save(id, build());
    expect((await repo.find(id))!.date, original);

    final moved = EntryDraft.fromEntry((await repo.find(id))!);
    await repo.save(
      id,
      EntryDraft(
        category: moved.category,
        title: moved.title,
        date: DateTime(2026, 9, 1),
      ),
    );
    expect((await repo.find(id))!.date, '2026-09-01');
  });

  test('a deleted entry can be restored, and the restore syncs', () async {
    final repo = EntryRepository(db);
    final id = await repo.create(build());
    await db.markEntriesClean([id]);

    await repo.delete(id);
    expect(await db.allEntries(), isEmpty);

    await repo.restore(id);
    final row = (await repo.find(id))!;
    expect(row.deletedAt, isNull);
    expect(row.dirty, isTrue);
    expect(await db.allEntries(), hasLength(1));
  });

  test('a deleted note can be restored', () async {
    final notes = NoteRepository(db);
    await notes.addBookNote('b1', 'Small wins.');
    final id = (await db.allNotes()).single.id;

    await notes.setDeleted(id, deleted: true);
    expect(await db.allNotes(), isEmpty);

    await notes.setDeleted(id, deleted: false);
    expect((await db.allNotes()).single.body, 'Small wins.');
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
