import 'dart:convert';

import '../database/database.dart';
import '../sync/row_mappers.dart';

/// Serialises the whole record into the two formats worth keeping.
///
/// Pure functions over rows — no file system, no Flutter — so the format is
/// testable without a device.
///
/// The JSON archive reuses [RowMappers], which means an export carries exactly
/// the shape the sync protocol already speaks. That is deliberate: the same
/// `*FromJson` constructors can read an archive back, so export is a restore
/// path and not just a read-only souvenir.
abstract final class TraceArchive {
  /// Bumped only when the shape changes in a way a reader must notice.
  static const formatVersion = 1;

  /// The complete record as a JSON-encodable map.
  ///
  /// Tombstones are the caller's business: pass live rows and the archive
  /// contains a clean record, pass everything and it contains the history of
  /// deletions too.
  static Map<String, dynamic> build({
    required List<Entry> entries,
    required List<Project> projects,
    required List<Book> books,
    required List<Note> notes,
    required DateTime exportedAt,
  }) {
    return {
      'format': 'trace.archive',
      'version': formatVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'counts': {
        'entries': entries.length,
        'projects': projects.length,
        'books': books.length,
        'notes': notes.length,
      },
      'entries': [for (final e in entries) RowMappers.entryToJson(e)],
      'projects': [for (final p in projects) RowMappers.projectToJson(p)],
      'books': [for (final b in books) RowMappers.bookToJson(b)],
      'notes': [for (final n in notes) RowMappers.noteToJson(n)],
    };
  }

  static String encodeJson(Map<String, dynamic> archive) =>
      const JsonEncoder.withIndent('  ').convert(archive);

  /// Entries as a spreadsheet, one row per entry, newest day first.
  ///
  /// Unlike the JSON archive this is for reading, not for restoring: ids are
  /// dropped and foreign keys are resolved to the names they point at, because
  /// a column of UUIDs helps nobody looking back at their year.
  static String entriesCsv(
    List<Entry> entries, {
    required List<Project> projects,
    required List<Book> books,
  }) {
    final projectNames = {for (final p in projects) p.id: p.name};
    final bookTitles = {for (final b in books) b.id: b.title};

    const headers = [
      'date',
      'category',
      'title',
      'description',
      'duration',
      'duration_secs',
      'quantity',
      'unit',
      'project',
      'book',
      'tags',
      'started_at',
      'ended_at',
    ];

    final sorted = [...entries]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });

    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final e in sorted) {
      buffer.writeln([
        e.date,
        e.category,
        e.title,
        e.description ?? '',
        e.durationSecs == null ? '' : formatDuration(e.durationSecs!),
        e.durationSecs?.toString() ?? '',
        _number(e.quantity),
        e.quantityUnit ?? '',
        e.projectId == null ? '' : projectNames[e.projectId] ?? '',
        e.bookId == null ? '' : bookTitles[e.bookId] ?? '',
        _tags(e.tags),
        e.startedAt?.toUtc().toIso8601String() ?? '',
        e.endedAt?.toUtc().toIso8601String() ?? '',
      ].map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  /// `2h 34m`, matching how durations read everywhere else in the app.
  static String formatDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// A trailing `.0` on a page count is noise; a real fraction is not.
  static String _number(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static String _tags(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is List ? decoded.join(' ') : '';
    } on FormatException {
      return '';
    }
  }

  /// RFC 4180: quote when the cell contains a comma, a quote or a newline, and
  /// double any quote inside it.
  static String _csvCell(String value) {
    if (!value.contains(RegExp(r'[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
