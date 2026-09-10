import 'dart:io';
import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import 'trace_archive.dart';

enum ExportFormat {
  /// The whole record, restorable. Same shape the sync protocol speaks.
  json,

  /// Entries only, readable in a spreadsheet.
  csv,
}

/// What the user got, so the screen can say so plainly.
class ExportOutcome {
  const ExportOutcome({required this.fileName, required this.rows});

  final String fileName;
  final int rows;
}

/// Writes the archive to a file and hands it to the system share sheet.
///
/// The file is staged in the cache directory, not in app documents: the share
/// sheet is the delivery mechanism, and the destination is wherever the user
/// sends it. Cache is the one directory the OS is free to reclaim, so the
/// staged copy does not quietly become a second permanent record.
class ExportService {
  const ExportService(this._db);

  final AppDatabase _db;

  Future<ExportOutcome> export(
    ExportFormat format, {
    Rect? sharePositionOrigin,
  }) async {
    final entries = await _db.allEntries();
    final projects = await _db.allProjects();
    final books = await _db.allBooks();
    final notes = await _db.allNotes();

    final now = DateTime.now();
    final stamp = DateFormat('yyyy-MM-dd').format(now);

    final (String name, String body, int rows) = switch (format) {
      ExportFormat.json => (
          'trace-$stamp.json',
          TraceArchive.encodeJson(
            TraceArchive.build(
              entries: entries,
              projects: projects,
              books: books,
              notes: notes,
              exportedAt: now,
            ),
          ),
          entries.length + projects.length + books.length + notes.length,
        ),
      ExportFormat.csv => (
          'trace-entries-$stamp.csv',
          TraceArchive.entriesCsv(entries, projects: projects, books: books),
          entries.length,
        ),
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(body, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'TRACE export · $stamp',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return ExportOutcome(fileName: name, rows: rows);
  }
}
