import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Translates between Drift rows and Data API JSON.
///
/// `dirty` and `synced_at` are local bookkeeping and never cross the wire.
/// `user_id` is never sent either — the column defaults to `auth.uid()`, so
/// ownership is decided by the token rather than claimed by the client.
abstract final class RowMappers {
  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();

  static DateTime _dateReq(Object? v) =>
      DateTime.parse(v! as String).toUtc();

  static double? _num(Object? v) => v == null ? null : (v as num).toDouble();

  // ── Entries ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> entryToJson(Entry e) => {
        'id': e.id,
        'category': e.category,
        'title': e.title,
        'description': e.description,
        'date': e.date,
        'started_at': _iso(e.startedAt),
        'ended_at': _iso(e.endedAt),
        'duration_secs': e.durationSecs,
        'quantity': e.quantity,
        'quantity_unit': e.quantityUnit,
        'project_id': e.projectId,
        'book_id': e.bookId,
        'tags': jsonDecode(e.tags),
        'created_at': _iso(e.createdAt),
        'updated_at': _iso(e.updatedAt),
        'deleted_at': _iso(e.deletedAt),
      };

  static EntriesCompanion entryFromJson(Map<String, dynamic> j) =>
      EntriesCompanion(
        id: Value(j['id'] as String),
        category: Value(j['category'] as String),
        title: Value(j['title'] as String),
        description: Value(j['description'] as String?),
        date: Value(j['date'] as String),
        startedAt: Value(_date(j['started_at'])),
        endedAt: Value(_date(j['ended_at'])),
        durationSecs: Value(j['duration_secs'] as int?),
        quantity: Value(_num(j['quantity'])),
        quantityUnit: Value(j['quantity_unit'] as String?),
        projectId: Value(j['project_id'] as String?),
        bookId: Value(j['book_id'] as String?),
        tags: Value(jsonEncode(j['tags'] ?? const [])),
        createdAt: Value(_dateReq(j['created_at'])),
        updatedAt: Value(_dateReq(j['updated_at'])),
        deletedAt: Value(_date(j['deleted_at'])),
        // Arrived from the server, so by definition it is in sync.
        dirty: const Value(false),
        syncedAt: Value(DateTime.now().toUtc()),
      );

  // ── Projects ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> projectToJson(Project p) => {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'status': p.status,
        'target_secs': p.targetSecs,
        'started_at': _iso(p.startedAt),
        'ended_at': _iso(p.endedAt),
        'created_at': _iso(p.createdAt),
        'updated_at': _iso(p.updatedAt),
        'deleted_at': _iso(p.deletedAt),
      };

  static ProjectsCompanion projectFromJson(Map<String, dynamic> j) =>
      ProjectsCompanion(
        id: Value(j['id'] as String),
        name: Value(j['name'] as String),
        description: Value(j['description'] as String?),
        status: Value(j['status'] as String),
        targetSecs: Value(j['target_secs'] as int?),
        startedAt: Value(_date(j['started_at'])),
        endedAt: Value(_date(j['ended_at'])),
        createdAt: Value(_dateReq(j['created_at'])),
        updatedAt: Value(_dateReq(j['updated_at'])),
        deletedAt: Value(_date(j['deleted_at'])),
        dirty: const Value(false),
        syncedAt: Value(DateTime.now().toUtc()),
      );

  // ── Books ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> bookToJson(Book b) => {
        'id': b.id,
        'title': b.title,
        'author': b.author,
        'cover_path': b.coverPath,
        'total_pages': b.totalPages,
        'status': b.status,
        'started_at': _iso(b.startedAt),
        'finished_at': _iso(b.finishedAt),
        'created_at': _iso(b.createdAt),
        'updated_at': _iso(b.updatedAt),
        'deleted_at': _iso(b.deletedAt),
      };

  static BooksCompanion bookFromJson(Map<String, dynamic> j) => BooksCompanion(
        id: Value(j['id'] as String),
        title: Value(j['title'] as String),
        author: Value(j['author'] as String?),
        coverPath: Value(j['cover_path'] as String?),
        totalPages: Value(j['total_pages'] as int?),
        status: Value(j['status'] as String),
        startedAt: Value(_date(j['started_at'])),
        finishedAt: Value(_date(j['finished_at'])),
        createdAt: Value(_dateReq(j['created_at'])),
        updatedAt: Value(_dateReq(j['updated_at'])),
        deletedAt: Value(_date(j['deleted_at'])),
        dirty: const Value(false),
        syncedAt: Value(DateTime.now().toUtc()),
      );

  // ── Notes ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> noteToJson(Note n) => {
        'id': n.id,
        'body': n.body,
        'kind': n.kind,
        'date': n.date,
        'entry_id': n.entryId,
        'project_id': n.projectId,
        'book_id': n.bookId,
        'created_at': _iso(n.createdAt),
        'updated_at': _iso(n.updatedAt),
        'deleted_at': _iso(n.deletedAt),
      };

  static NotesCompanion noteFromJson(Map<String, dynamic> j) => NotesCompanion(
        id: Value(j['id'] as String),
        body: Value(j['body'] as String),
        kind: Value(j['kind'] as String),
        date: Value(j['date'] as String?),
        entryId: Value(j['entry_id'] as String?),
        projectId: Value(j['project_id'] as String?),
        bookId: Value(j['book_id'] as String?),
        createdAt: Value(_dateReq(j['created_at'])),
        updatedAt: Value(_dateReq(j['updated_at'])),
        deletedAt: Value(_date(j['deleted_at'])),
        dirty: const Value(false),
        syncedAt: Value(DateTime.now().toUtc()),
      );
}
