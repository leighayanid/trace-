import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
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
  Future<String> create(EntryDraft draft, {DateTime? on}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();

    await _db.upsertEntry(
      EntriesCompanion.insert(
        id: id,
        category: draft.category.name,
        title: draft.title,
        date: dayKey(on ?? DateTime.now()),
        createdAt: now,
        updatedAt: now,
        description: Value(_text(draft.description)),
        durationSecs: Value(draft.duration?.inSeconds),
        quantity: Value(draft.quantity),
        quantityUnit: Value(draft.quantity == null ? null : draft.quantityUnit),
        projectId: Value(_projectOf(draft)),
        bookId: Value(_bookOf(draft)),
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
        description: Value(_text(draft.description)),
        durationSecs: Value(draft.duration?.inSeconds),
        quantity: Value(draft.quantity),
        quantityUnit: Value(draft.quantity == null ? null : draft.quantityUnit),
        projectId: Value(_projectOf(draft)),
        bookId: Value(_bookOf(draft)),
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

  static String? _text(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Future<void> _settle(String? bookId) async {
    if (bookId != null) await _db.settleBookStatus(bookId);
  }

  /// Tombstone, not a hard delete.
  Future<void> delete(String id) => _db.softDeleteEntry(id);
}

/// Convenience view over a row for the UI layer.
extension EntryView on Entry {
  Category get categoryEnum =>
      Category.tryParse(category) ?? Category.build;

  Duration? get durationOrNull =>
      durationSecs == null ? null : Duration(seconds: durationSecs!);
}
