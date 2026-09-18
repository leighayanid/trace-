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

  /// Logs a reading session: a READ entry of [pagesRead] pages.
  ///
  /// The bookmark is derived from these entries, so writing the session is
  /// all it takes to move it — there is no second number to keep in step.
  Future<void> logSession({
    required Book book,
    required int pagesRead,
    String? thought,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
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
      await _db.settleBookStatus(book.id);
    });
  }

  Future<void> update({
    required String id,
    String? title,
    String? author,
    int? totalPages,
    BookStatus? status,
  }) {
    return _db.updateBook(
      BooksCompanion(
        id: Value(id),
        title: title == null ? const Value.absent() : Value(title.trim()),
        author: author == null ? const Value.absent() : Value(author.trim()),
        totalPages:
            totalPages == null ? const Value.absent() : Value(totalPages),
        status: status == null ? const Value.absent() : Value(status.key),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }
}

/// Where a book stands, from the pages logged against it.
///
/// [pagesRead] comes from [AppDatabase.watchPagesRead]. Rereading past the end
/// is allowed in the log but not on the bookmark, which stops at the last page.
extension BookProgress on Book {
  int currentPage(int pagesRead) =>
      totalPages == null ? pagesRead : pagesRead.clamp(0, totalPages!);

  /// 0–1, or null when there is no page count to measure against.
  double? progress(int pagesRead) => totalPages == null || totalPages == 0
      ? null
      : currentPage(pagesRead) / totalPages!;
}
