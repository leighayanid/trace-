import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';

/// Notes: the ONE LINE, reading thoughts, quotes, and free notes.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<Note?> watchOneLine(String date) => _db.watchOneLine(date);

  /// Writes the day's one line, replacing it if one already exists.
  ///
  /// An empty body tombstones the note rather than storing a blank — the field
  /// is optional, and "cleared" should not read as "written nothing".
  Future<void> setOneLine(String date, String body) async {
    final existing = await _db.watchOneLine(date).first;
    final now = DateTime.now().toUtc();
    final trimmed = body.trim();

    if (existing == null) {
      if (trimmed.isEmpty) return;
      await _db.upsertNote(
        NotesCompanion.insert(
          id: _uuid.v7(),
          body: trimmed,
          kind: const Value('one_line'),
          date: Value(date),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    await _db.updateNote(
      NotesCompanion(
        id: Value(existing.id),
        body: Value(trimmed),
        updatedAt: Value(now),
        deletedAt: Value(trimmed.isEmpty ? now : null),
        dirty: const Value(true),
      ),
    );
  }

  /// Tombstones a note, or clears the tombstone to undo that.
  Future<void> setDeleted(String id, {required bool deleted}) {
    final now = DateTime.now().toUtc();
    return _db.updateNote(
      NotesCompanion(
        id: Value(id),
        deletedAt: Value(deleted ? now : null),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// A free note attached to a book — used for reading thoughts and quotes.
  Future<void> addBookNote(String bookId, String body,
      {String kind = 'thought'}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().toUtc();
    await _db.upsertNote(
      NotesCompanion.insert(
        id: _uuid.v7(),
        body: trimmed,
        kind: Value(kind),
        bookId: Value(bookId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
