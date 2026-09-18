import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../sync/conflict.dart';
import '../sync/row_mappers.dart';
import 'trace_archive.dart';

/// What an import did, so the screen can say so plainly.
class ImportOutcome {
  const ImportOutcome({
    required this.added,
    required this.updated,
    required this.kept,
  });

  /// Rows this device did not have.
  final int added;

  /// Rows the archive had a newer edit of.
  final int updated;

  /// Rows where this device's copy was as new or newer, left alone.
  final int kept;
}

/// Reads a JSON export back in.
///
/// A merge, never a replace: each row is judged the way sync judges it — the
/// later edit wins — so importing an old backup cannot undo newer work, and
/// importing the same file twice changes nothing the second time. Nothing
/// local is deleted.
///
/// Rows that land are marked dirty, so a signed-in device sends them on to the
/// server like any other edit.
class ImportService {
  const ImportService(this._db);

  final AppDatabase _db;

  static const _dirty = Value(true);
  static const _unsynced = Value<DateTime?>(null);

  /// Throws a [FormatException] with a message fit to show when [text] is not
  /// a readable archive. Nothing is written in that case.
  Future<ImportOutcome> importJson(String text) async {
    final rows = TraceArchive.parse(text);
    var added = 0, updated = 0, kept = 0;

    Future<void> merge(
      List<Map<String, dynamic>> table,
      Future<SyncRow?> Function(String id) localOf,
      Future<void> Function(Map<String, dynamic> json) write,
    ) async {
      for (final json in table) {
        final local = await localOf(json['id'] as String);
        final incoming = DateTime.parse(json['updated_at'] as String).toUtc();
        if (local == null) {
          added++;
        } else if (incoming.isAfter(local.updatedAt)) {
          updated++;
        } else {
          kept++;
          continue;
        }
        await write(json);
      }
    }

    try {
      // One transaction, so a file that fails half way imports nothing.
      // Projects and books first: entries and notes refer to them.
      await _db.transaction(() async {
        await merge(rows.projects, _db.projectSyncRow, (j) =>
            _db.upsertProject(RowMappers.projectFromJson(j)
                .copyWith(dirty: _dirty, syncedAt: _unsynced)));
        await merge(rows.books, _db.bookSyncRow, (j) =>
            _db.upsertBook(RowMappers.bookFromJson(j)
                .copyWith(dirty: _dirty, syncedAt: _unsynced)));
        await merge(rows.entries, _db.entrySyncRow, (j) =>
            _db.upsertEntry(RowMappers.entryFromJson(j)
                .copyWith(dirty: _dirty, syncedAt: _unsynced)));
        await merge(rows.notes, _db.noteSyncRow, (j) =>
            _db.upsertNote(RowMappers.noteFromJson(j)
                .copyWith(dirty: _dirty, syncedAt: _unsynced)));
      });
    } on TypeError {
      // A row missing a field, or holding the wrong type.
      throw const FormatException('That export is damaged.');
    } on FormatException {
      // A date that does not parse.
      throw const FormatException('That export is damaged.');
    }

    return ImportOutcome(added: added, updated: updated, kept: kept);
  }
}
