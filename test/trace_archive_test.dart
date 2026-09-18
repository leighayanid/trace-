import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/export/trace_archive.dart';
import 'package:trace/core/sync/row_mappers.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12, 0);

  Entry entry({
    String id = 'e1',
    String category = 'build',
    String title = 'PDS Express',
    String? description,
    String date = '2026-09-10',
    int? durationSecs = 9240,
    double? quantity,
    String? quantityUnit,
    String? projectId,
    String? bookId,
    String tags = '[]',
  }) {
    return Entry(
      id: id,
      category: category,
      title: title,
      description: description,
      date: date,
      durationSecs: durationSecs,
      quantity: quantity,
      quantityUnit: quantityUnit,
      projectId: projectId,
      bookId: bookId,
      tags: tags,
      createdAt: t0,
      updatedAt: t0,
      dirty: false,
    );
  }

  Project project({String id = 'p1', String name = 'PDS Express'}) => Project(
        id: id,
        name: name,
        status: 'active',
        createdAt: t0,
        updatedAt: t0,
        dirty: false,
      );

  Book book({
    String id = 'b1',
    String title = 'The Design of Everyday Things',
  }) =>
      Book(
        id: id,
        title: title,
        status: 'reading',
        createdAt: t0,
        updatedAt: t0,
        dirty: false,
      );

  Note note({String id = 'n1', String body = 'Figured out the shape of it.'}) =>
      Note(
        id: id,
        body: body,
        kind: 'one_line',
        date: '2026-09-10',
        createdAt: t0,
        updatedAt: t0,
        dirty: false,
      );

  Map<String, dynamic> archiveOf({
    List<Entry> entries = const [],
    List<Project> projects = const [],
    List<Book> books = const [],
    List<Note> notes = const [],
  }) {
    return TraceArchive.build(
      entries: entries,
      projects: projects,
      books: books,
      notes: notes,
      exportedAt: t0,
    );
  }

  group('TraceArchive.build', () {
    test('stamps the format so a future reader can tell what it has', () {
      final a = archiveOf();
      expect(a['format'], 'trace.archive');
      expect(a['version'], TraceArchive.formatVersion);
      expect(a['exported_at'], '2026-09-10T12:00:00.000Z');
    });

    test('counts match the rows actually written', () {
      final a = archiveOf(
        entries: [entry(), entry(id: 'e2')],
        projects: [project()],
        books: [book()],
        notes: [note()],
      );
      expect(a['counts'], {
        'entries': 2,
        'projects': 1,
        'books': 1,
        'notes': 1,
      });
      expect((a['entries'] as List).length, 2);
    });

    test('the whole archive survives a JSON round trip', () {
      final a = archiveOf(entries: [entry()], projects: [project()]);
      final decoded =
          jsonDecode(TraceArchive.encodeJson(a)) as Map<String, dynamic>;
      expect(decoded['counts'], a['counts']);
      expect((decoded['entries'] as List).first, (a['entries'] as List).first);
    });
  });

  group('archive rows are restorable', () {
    // The point of reusing RowMappers: an export is not a souvenir, it is a
    // payload the app can read back.
    test('an exported entry reloads into the database unchanged', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final original = entry(
        description: 'Router work',
        quantity: 3,
        quantityUnit: 'sessions',
        projectId: 'p1',
        tags: '["router","dart"]',
      );
      final encoded = TraceArchive.encodeJson(archiveOf(entries: [original]));
      final json = jsonDecode(encoded) as Map<String, dynamic>;

      await db.upsertEntry(
        RowMappers.entryFromJson(
          (json['entries'] as List).first as Map<String, dynamic>,
        ),
      );

      final restored = await db.findEntry('e1');
      expect(restored, isNotNull);
      expect(restored!.title, original.title);
      expect(restored.description, 'Router work');
      expect(restored.durationSecs, 9240);
      expect(restored.quantity, 3);
      expect(restored.quantityUnit, 'sessions');
      expect(restored.projectId, 'p1');
      expect(jsonDecode(restored.tags), ['router', 'dart']);
    });
  });

  group('TraceArchive.entriesCsv', () {
    test('the header names the columns a spreadsheet will show', () {
      final csv = TraceArchive.entriesCsv(
        const [],
        projects: const [],
        books: const [],
      );
      expect(
        csv.trim(),
        startsWith('date,category,title,description,duration,'),
      );
    });

    test('foreign keys are resolved to names, not left as ids', () {
      final csv = TraceArchive.entriesCsv(
        [
          entry(projectId: 'p1'),
          entry(id: 'e2', bookId: 'b1', title: 'Reading'),
        ],
        projects: [project()],
        books: [book()],
      );
      expect(csv, contains('PDS Express'));
      expect(csv, contains('The Design of Everyday Things'));
    });

    test('a dangling foreign key leaves the cell empty rather than throwing',
        () {
      final csv = TraceArchive.entriesCsv(
        [entry(projectId: 'gone')],
        projects: const [],
        books: const [],
      );
      expect(csv, isNot(contains('gone')));
    });

    test('durations read the way they do in the app', () {
      expect(TraceArchive.formatDuration(9240), '2h 34m');
      expect(TraceArchive.formatDuration(1920), '32m');
      expect(TraceArchive.formatDuration(7200), '2h');
    });

    test('a whole quantity does not export a trailing .0', () {
      final csv = TraceArchive.entriesCsv(
        [entry(durationSecs: null, quantity: 27, quantityUnit: 'pages')],
        projects: const [],
        books: const [],
      );
      expect(csv, contains(',27,pages,'));
    });

    test('commas and quotes are escaped per RFC 4180', () {
      final csv = TraceArchive.entriesCsv(
        [entry(title: 'Read, then wrote', description: 'He said "hello"')],
        projects: const [],
        books: const [],
      );
      expect(csv, contains('"Read, then wrote"'));
      expect(csv, contains('"He said ""hello"""'));
    });

    test('a newline inside a cell is quoted rather than breaking the row', () {
      final csv = TraceArchive.entriesCsv(
        [entry(description: 'first\nsecond')],
        projects: const [],
        books: const [],
      );
      expect(csv, contains('"first\nsecond"'));
    });

    test('rows come out newest day first', () {
      final csv = TraceArchive.entriesCsv(
        [
          entry(id: 'old', date: '2026-09-08', title: 'Older'),
          entry(id: 'new', date: '2026-09-10', title: 'Newer'),
        ],
        projects: const [],
        books: const [],
      );
      expect(csv.indexOf('Newer'), lessThan(csv.indexOf('Older')));
    });

    test('tags become a plain space-separated cell', () {
      final csv = TraceArchive.entriesCsv(
        [entry(tags: '["dart","drift"]')],
        projects: const [],
        books: const [],
      );
      expect(csv, contains('dart drift'));
    });

    test('malformed tags do not take the export down with them', () {
      final csv = TraceArchive.entriesCsv(
        [entry(tags: 'not json')],
        projects: const [],
        books: const [],
      );
      expect(csv, contains('build'));
    });
  });
}
