import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/parser/entry_parser.dart';
import 'package:trace/core/sync/sync_engine.dart';
import 'package:trace/features/entries/entry_draft.dart';
import 'package:trace/features/entries/entry_repository.dart';
import 'package:trace/features/reading/book_repository.dart';

import 'support/fake_server.dart';

/// The bookmark is the sum of a book's sessions, however they were logged.
void main() {
  late AppDatabase db;
  late BookRepository books;
  late EntryRepository entries;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    books = BookRepository(db);
    entries = EntryRepository(db);
  });
  tearDown(() => db.close());

  Future<Book> atomicHabits({int? totalPages = 300}) async {
    await books.create(title: 'Atomic Habits', totalPages: totalPages);
    return (await db.allBooks()).single;
  }

  Future<String> quickAdd(Book book, String text) {
    final parser = EntryParser(books: [NamedRef(book.id, book.title)]);
    return entries.create(
      EntryDraft.fromParsed(parser.parse(text), today: DateTime.now()),
    );
  }

  test('logging reading moves the bookmark and records a session', () async {
    final book = await atomicHabits();

    await books.logSession(book: book, pagesRead: 27, thought: 'Small wins.');

    expect(await db.pagesRead(book.id), 27);
    final session = (await db.allEntries()).single;
    expect(session.quantity, 27);
    expect(session.description, 'Small wins.');
  });

  test('pages typed into Quick Add move the bookmark too', () async {
    final book = await atomicHabits();

    await quickAdd(book, 'read 27 pages of Atomic Habits');

    expect(await db.pagesRead(book.id), 27);
  });

  test('deleting a session moves the bookmark back', () async {
    final book = await atomicHabits();
    await books.logSession(book: book, pagesRead: 20);
    final mistake = await quickAdd(book, 'read 40 pages of Atomic Habits');

    await entries.delete(mistake);

    expect(await db.pagesRead(book.id), 20);
  });

  test('editing a session to another book moves both bookmarks', () async {
    final book = await atomicHabits();
    final other = await books.create(title: 'Deep Work', totalPages: 280);
    final id = await quickAdd(book, 'read 30 pages of Atomic Habits');

    final draft = EntryDraft.fromEntry((await entries.find(id))!);
    await entries.save(
      id,
      EntryDraft(
        category: draft.category,
        title: 'Deep Work',
        quantity: draft.quantity,
        quantityUnit: draft.quantityUnit,
        bookId: other,
      ),
    );

    expect(await db.pagesRead(book.id), 0);
    expect(await db.pagesRead(other), 30);
  });

  test('reaching the last page finishes the book, whichever way it was logged',
      () async {
    final book = await atomicHabits(totalPages: 50);
    await books.logSession(book: book, pagesRead: 30);
    expect((await db.allBooks()).single.status, 'reading');

    await quickAdd(book, 'read 20 pages of Atomic Habits');

    final finished = (await db.allBooks()).single;
    expect(finished.status, 'finished');
    expect(finished.finishedAt, isNotNull);
  });

  test('the bookmark stops at the last page', () async {
    final book = await atomicHabits(totalPages: 50);
    expect(book.currentPage(70), 50);
    expect(book.progress(70), 1.0);
    expect(book.progress(25), 0.5);

    final open = book.copyWith(totalPages: const Value(null));
    expect(open.currentPage(70), 70);
    expect(open.progress(70), isNull);
  });

  test('sessions logged offline on two devices both count', () async {
    // A stored running total kept only one device's increment: last-write-wins
    // picks one book row. Sessions are separate rows, so both survive.
    final server = FakeServer();
    final tablet = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(tablet.close);
    final phoneSync = SyncEngine(db: db, api: server);
    final tabletSync = SyncEngine(db: tablet, api: server);

    final book = await atomicHabits();
    await phoneSync.sync();
    await tabletSync.sync();

    await books.logSession(book: book, pagesRead: 12);
    await BookRepository(tablet)
        .logSession(book: (await tablet.allBooks()).single, pagesRead: 30);

    await phoneSync.sync();
    await tabletSync.sync();
    await phoneSync.sync();

    expect(await db.pagesRead(book.id), 42);
    expect(await tablet.pagesRead(book.id), 42);
  });
}
