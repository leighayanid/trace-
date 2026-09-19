import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/models/category.dart';
import 'entry_draft.dart';

/// ISO day key, `yyyy-MM-dd`. The unit the whole app groups by.
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Writes and reads entries. The only place entry rows are constructed.
class EntryRepository {
  EntryRepository(this._db);

  final AppDatabase _db;

  /// v7 so ids sort by creation time, which makes sync pages stable.
  static const _uuid = Uuid();

  Stream<List<Entry>> watchForDate(String date) => _db.watchEntriesForDate(date);

  Future<Entry?> find(String id) => _db.findEntry(id);

  /// Persists a new entry. Returns its id.
  Future<String> create(EntryDraft draft) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();

    await _db.upsertEntry(
      EntriesCompanion.insert(
        id: id,
        category: draft.category.name,
        title: draft.title,
        date: dayKey(draft.date ?? DateTime.now()),
        createdAt: now,
        updatedAt: now,
        description: Value(_text(draft.description)),
        durationSecs: Value(draft.duration?.inSeconds),
        quantity: Value(draft.quantity),
        quantityUnit: Value(draft.quantity == null ? null : draft.quantityUnit),
        projectId: Value(_projectOf(draft)),
        bookId: Value(_bookOf(draft)),
        parentId: Value(await _parentOf(draft, id)),
      ),
    );
    await _settle(_bookOf(draft));
    return id;
  }

  /// Writes every editable field of [draft] over the entry — including nulls,
  /// so a cleared field is cleared. Always bumps `updatedAt` and re-marks the
  /// row dirty; those two are what make it win a last-write-wins
  /// reconciliation.
  Future<void> save(String id, EntryDraft draft) async {
    await _db.updateEntry(
      EntriesCompanion(
        id: Value(id),
        category: Value(draft.category.name),
        title: Value(draft.title),
        // A draft without a day keeps the entry's own; it never means "move to
        // today".
        date: draft.date == null
            ? const Value.absent()
            : Value(dayKey(draft.date!)),
        description: Value(_text(draft.description)),
        durationSecs: Value(draft.duration?.inSeconds),
        quantity: Value(draft.quantity),
        quantityUnit: Value(draft.quantity == null ? null : draft.quantityUnit),
        projectId: Value(_projectOf(draft)),
        bookId: Value(_bookOf(draft)),
        parentId: Value(await _parentOf(draft, id)),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
    await _settle(_bookOf(draft));
  }

  // A project belongs to BUILD and a book to READ. The form hides the field
  // for other categories, so a link left over from before a category change
  // must not be saved invisibly.
  static String? _projectOf(EntryDraft d) =>
      d.category == Category.build ? d.projectId : null;
  static String? _bookOf(EntryDraft d) =>
      d.category == Category.read ? d.bookId : null;

  /// A rabbit hole is EXPLORE entries leading on from each other. A link that
  /// would lead back to the entry itself — directly or through its chain — is
  /// dropped, so a chain always has a start.
  Future<String?> _parentOf(EntryDraft d, String id) async {
    final parent = d.category == Category.explore ? d.parentId : null;
    if (parent == null || parent == id) return null;
    final above = await _db.ancestorsOf(parent);
    return above.any((e) => e.id == id) ? null : parent;
  }

  static String? _text(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<void> _settle(String? bookId) async {
    if (bookId != null) await _db.settleBookStatus(bookId);
  }

  /// Tombstone, not a hard delete.
  Future<void> delete(String id) => _db.softDeleteEntry(id);

  /// Undoes [delete]. The restore is a fresh edit, so it also wins over a
  /// tombstone that already reached the server.
  Future<void> restore(String id) async {
    await _db.restoreEntry(id);
    await _settle((await _db.findEntry(id))?.bookId);
  }
}

/// Convenience view over a row for the UI layer.
extension EntryView on Entry {
  Category get categoryEnum =>
      Category.tryParse(category) ?? Category.build;

  Duration? get durationOrNull =>
      durationSecs == null ? null : Duration(seconds: durationSecs!);

  /// `32 pages` for a row's value column — only when there is no duration,
  /// which takes the column when both exist.
  String? get quantityLabel {
    if (quantity == null || quantityUnit == null) return null;
    if (durationSecs != null) return null;
    return QuantityGrammar.format(quantity!, quantityUnit!);
  }
}
