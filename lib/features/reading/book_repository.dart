import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../shared/models/category.dart';
import '../entries/entry_repository.dart';

enum BookStatus {
  want('want', 'Want to Read'),
  reading('reading', 'Reading'),
  finished('finished', 'Finished'),
  abandoned('abandoned', 'Abandoned');

  const BookStatus(this.key, this.label);
  final String key;
  final String label;

  static BookStatus parse(String v) => BookStatus.values
      .firstWhere((s) => s.key == v, orElse: () => BookStatus.reading);
}

class BookRepository {
  BookRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Book>> watchAll() => _db.watchBooks();

  Stream<List<Entry>> watchSessions(String bookId) =>
      _db.watchEntriesForBook(bookId);

  Future<String> create({
    required String title,
    String? author,
    int? totalPages,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();
    await _db.upsertBook(
      BooksCompanion.insert(
        id: id,
        title: title.trim(),
        author: Value(author?.trim()),
        totalPages: Value(totalPages),
        startedAt: Value(now),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Logs a reading session.
  ///
  /// One action writes two things — a READ entry and the book's new page —
  /// because a reading session that does not move the bookmark is a session the
  /// user has to record twice.
  Future<void> logSession({
    required Book book,
    required int pagesRead,
    String? thought,
  }) async {
    final now = DateTime.now().toUtc();
    final newPage = (book.currentPage + pagesRead)
        .clamp(0, book.totalPages ?? 1 << 30);
    final finished =
        book.totalPages != null && newPage >= book.totalPages!;

    await _db.updateBook(
      BooksCompanion(
        id: Value(book.id),
        currentPage: Value(newPage),
        status: Value(finished ? BookStatus.finished.key : book.status),
        finishedAt: finished ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );

    await _db.upsertEntry(
      EntriesCompanion.insert(
        id: _uuid.v7(),
        category: Category.read.name,
        title: book.title,
        date: dayKey(DateTime.now()),
        quantity: Value(pagesRead.toDouble()),
        quantityUnit: const Value('pages'),
        bookId: Value(book.id),
        description: Value(thought?.trim().isEmpty ?? true ? null : thought),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> update({
    required String id,
    String? title,
    String? author,
    int? currentPage,
    int? totalPages,
    BookStatus? status,
  }) {
    return _db.updateBook(
      BooksCompanion(
        id: Value(id),
        title: title == null ? const Value.absent() : Value(title.trim()),
        author: author == null ? const Value.absent() : Value(author.trim()),
        currentPage:
            currentPage == null ? const Value.absent() : Value(currentPage),
        totalPages:
            totalPages == null ? const Value.absent() : Value(totalPages),
        status: status == null ? const Value.absent() : Value(status.key),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }
}
