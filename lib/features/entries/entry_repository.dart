import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/parser/entry_parser.dart';
import '../../shared/models/category.dart';

/// ISO day key, `yyyy-MM-dd`. The unit the whole app groups by.
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Writes and reads entries. The only place entry rows are constructed.
class EntryRepository {
  EntryRepository(this._db);

  final AppDatabase _db;

  /// v7 so ids sort by creation time, which makes sync pages stable.
  static const _uuid = Uuid();

  Stream<List<Entry>> watchForDate(String date) => _db.watchEntriesForDate(date);

  Stream<List<DayGroup>> watchTimeline() => _db.watchTimeline();

  Future<Entry?> find(String id) => _db.findEntry(id);

  /// Persists a parsed entry. Returns the new id.
  Future<String> createFromParsed(ParsedEntry parsed, {DateTime? on}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();

    await _db.upsertEntry(
      EntriesCompanion.insert(
        id: id,
        category: parsed.category.name,
        title: parsed.title.isEmpty ? parsed.raw : parsed.title,
        date: dayKey(on ?? DateTime.now()),
        createdAt: now,
        updatedAt: now,
        description: const Value.absent(),
        durationSecs: Value(parsed.duration?.inSeconds),
        quantity: Value(parsed.quantity),
        quantityUnit: Value(parsed.quantityUnit),
        projectId: Value(parsed.projectId),
        bookId: Value(parsed.bookId),
      ),
    );
    return id;
  }

  /// Edits an existing entry. Always bumps `updatedAt` and re-marks it dirty —
  /// those two are what make the row win a last-write-wins reconciliation.
  Future<void> update({
    required String id,
    Category? category,
    String? title,
    String? description,
    Duration? duration,
    double? quantity,
    String? quantityUnit,
    String? projectId,
    String? bookId,
  }) async {
    await _db.updateEntry(
      EntriesCompanion(
        id: Value(id),
        category: category == null ? const Value.absent() : Value(category.name),
        title: title == null ? const Value.absent() : Value(title),
        description:
            description == null ? const Value.absent() : Value(description),
        durationSecs:
            duration == null ? const Value.absent() : Value(duration.inSeconds),
        quantity: quantity == null ? const Value.absent() : Value(quantity),
        quantityUnit:
            quantityUnit == null ? const Value.absent() : Value(quantityUnit),
        projectId: projectId == null ? const Value.absent() : Value(projectId),
        bookId: bookId == null ? const Value.absent() : Value(bookId),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
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
