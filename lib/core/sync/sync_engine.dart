
import '../database/database.dart';
import 'conflict.dart';
import 'data_api_client.dart';
import 'row_mappers.dart';

/// Where a sync currently stands. A sealed class rather than freezed — Dart 3
/// covers this without a code generator.
sealed class SyncStatus {
  const SyncStatus();
}

class SyncIdle extends SyncStatus {
  const SyncIdle(this.lastSyncedAt);
  final DateTime? lastSyncedAt;
}

class SyncRunning extends SyncStatus {
  const SyncRunning();
}

class SyncFailed extends SyncStatus {
  const SyncFailed(this.message);
  final String message;
}

/// Reconciles local SQLite with Neon.
///
/// Push first, then pull. That ordering matters: pushing first means a local
/// edit is already on the server when the pull runs, so the two cannot disagree
/// about a row this device just changed.
///
/// Proofs are deliberately excluded — proof capture is not built, so the table
/// is always empty. Add it here when it exists.
class SyncEngine {
  SyncEngine({required AppDatabase db, required DataApiClient api})
      : _db = db,
        _api = api;

  final AppDatabase _db;
  final DataApiClient _api;

  static const _batchSize = 200;

  bool _running = false;

  /// Runs one full reconciliation.
  ///
  /// Concurrent calls are ignored rather than queued: two syncs racing would
  /// interleave pushes and pulls and could resurrect a row deleted mid-flight.
  Future<SyncStatus> sync() async {
    if (_running) return const SyncRunning();
    _running = true;
    try {
      await _pushAll();
      await _pullAll();

      final now = DateTime.now().toUtc();
      await _db.updateSyncState(lastPushAt: now, error: null);
      return SyncIdle(now);
    } catch (e) {
      // Failure is quiet by design: it lands in sync_state and surfaces as one
      // muted line in Settings. No banner, no modal.
      final message = _describe(e);
      await _db.updateSyncState(error: message);
      return SyncFailed(message);
    } finally {
      _running = false;
    }
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  Future<void> _pushAll() async {
    await _push(
      table: 'projects',
      rows: await _db.dirtyProjects(),
      toJson: RowMappers.projectToJson,
      clear: (ids) => _db.markProjectsClean(ids),
    );
    await _push(
      table: 'books',
      rows: await _db.dirtyBooks(),
      toJson: RowMappers.bookToJson,
      clear: (ids) => _db.markBooksClean(ids),
    );
    // Entries reference projects and books, so those go first — otherwise the
    // foreign keys would not yet exist on the server.
    await _push(
      table: 'entries',
      rows: await _db.dirtyEntries(),
      toJson: RowMappers.entryToJson,
      clear: (ids) => _db.markEntriesClean(ids),
    );
    await _push(
      table: 'notes',
      rows: await _db.dirtyNotes(),
      toJson: RowMappers.noteToJson,
      clear: (ids) => _db.markNotesClean(ids),
    );
  }

  Future<void> _push<T>({
    required String table,
    required List<T> rows,
    required Map<String, dynamic> Function(T) toJson,
    required Future<void> Function(List<String>) clear,
  }) async {
    for (var i = 0; i < rows.length; i += _batchSize) {
      final batch = rows.sublist(
        i,
        (i + _batchSize).clamp(0, rows.length),
      );
      final payload = batch.map(toJson).toList();
      await _api.push(table: table, rows: payload);
      // Only cleared after the server has accepted them; a failure mid-way
      // leaves the rest dirty and they are retried next sync.
      await clear([for (final row in payload) row['id'] as String]);
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullAll() async {
    final state = await _db.syncState();
    var cursor = state?.lastPullCursor;

    // One cursor across all tables. Simple, and safe because it only ever moves
    // to a timestamp every table has been read up to.
    cursor = await _pull(
      table: 'projects',
      cursor: cursor,
      apply: (json) => _db.upsertProject(RowMappers.projectFromJson(json)),
      localOf: (id) => _db.projectSyncRow(id),
    );
    cursor = await _pull(
      table: 'books',
      cursor: cursor,
      apply: (json) => _db.upsertBook(RowMappers.bookFromJson(json)),
      localOf: (id) => _db.bookSyncRow(id),
    );
    cursor = await _pull(
      table: 'entries',
      cursor: cursor,
      apply: (json) => _db.upsertEntry(RowMappers.entryFromJson(json)),
      localOf: (id) => _db.entrySyncRow(id),
    );
    cursor = await _pull(
      table: 'notes',
      cursor: cursor,
      apply: (json) => _db.upsertNote(RowMappers.noteFromJson(json)),
      localOf: (id) => _db.noteSyncRow(id),
    );

    if (cursor != null) {
      await _db.updateSyncState(cursor: cursor);
    }
  }

  Future<DateTime?> _pull({
    required String table,
    required DateTime? cursor,
    required Future<void> Function(Map<String, dynamic>) apply,
    required Future<SyncRow?> Function(String id) localOf,
  }) async {
    var current = cursor;

    while (true) {
      final page = await _api.pull(table: table, cursor: current);
      if (page.isEmpty) break;

      final seen = <DateTime>[];
      for (final json in page) {
        final remoteUpdated =
            DateTime.parse(json['updated_at'] as String).toUtc();
        seen.add(remoteUpdated);

        final local = await localOf(json['id'] as String);
        final decision = Conflict.resolve(
          local: local,
          remoteUpdatedAt: remoteUpdated,
        );
        // keepLocal leaves the row dirty, so the next push sends it.
        if (decision == Resolution.takeRemote) await apply(json);
      }

      current = Conflict.advanceCursor(current: current, received: seen);
      if (page.length < DataApiClient.pageSize) break;
    }

    return current;
  }

  static String _describe(Object e) {
    final text = e.toString();
    // Never surface a raw exception: it can carry URLs and, from the auth
    // layer, token material.
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return 'No connection';
    }
    if (text.contains('Not signed in')) return 'Not signed in';
    if (text.contains('401') || text.contains('403')) {
      return 'Sign-in expired';
    }
    return 'Sync failed';
  }
}
