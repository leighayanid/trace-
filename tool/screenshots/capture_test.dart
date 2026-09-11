// Renders the real screens, with a seeded record, into docs/screenshots/.
//
//   flutter test tool/screenshots/capture_test.dart
//
// Lives outside test/ so a plain `flutter test` never rewrites the images. It
// asserts nothing; it is a camera, not a test.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:trace/app/theme/theme.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/database/database_provider.dart';
import 'package:trace/features/entries/quick_add_sheet.dart';
import 'package:trace/features/insights/insights_screen.dart';
import 'package:trace/features/projects/projects_screen.dart';
import 'package:trace/features/reading/book_detail_screen.dart';
import 'package:trace/features/timeline/timeline_screen.dart';
import 'package:trace/features/today/today_screen.dart';
import 'package:trace/shared/widgets/trace_nav_bar.dart';
import 'package:trace/shared/widgets/trace_sheet.dart';

const _outDir = 'docs/screenshots';

/// A 390 × 844 phone at 2x — sharp on a retina screen, light enough for a page.
const _size = Size(390, 844);
const _dpr = 2.0;

final _boundary = GlobalKey();

void main() {
  setUpAll(() async {
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode.name;

    testWidgets('today ($suffix)', (tester) async {
      await _pump(
        tester,
        mode,
        _Tab(index: 0, child: TodayScreen(onAddEntry: () {})),
      );
      await _shot(tester, 'today-$suffix');
    });

    testWidgets('quick add ($suffix)', (tester) async {
      await _pump(
        tester,
        mode,
        _Tab(index: 0, child: TodayScreen(onAddEntry: () {})),
      );
      showTraceSheet<void>(
        context: tester.element(find.byType(TodayScreen)),
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (_) => QuickAddSheet(onEditDetails: (_) {}),
      );
      await _settle(tester);
      await tester.enterText(
        find.byType(TextField),
        'coded for 2 hours on PDS Express',
      );
      await _shot(tester, 'quick-add-$suffix');

      await tester.tap(find.text('Continue'));
      await _shot(tester, 'quick-add-confirm-$suffix');
    });

    testWidgets('timeline ($suffix)', (tester) async {
      await _pump(tester, mode, const _Tab(index: 1, child: TimelineScreen()));
      await _shot(tester, 'timeline-$suffix');
    });

    testWidgets('projects ($suffix)', (tester) async {
      await _pump(tester, mode, const _Tab(index: 2, child: ProjectsScreen()));
      await _shot(tester, 'projects-$suffix');
    });

    testWidgets('reading ($suffix)', (tester) async {
      await _pump(tester, mode, const BookDetailScreen(bookId: 'b-doet'));
      await _shot(tester, 'reading-$suffix');
    });

    testWidgets('insights ($suffix)', (tester) async {
      await _pump(tester, mode, const InsightsScreen());
      await _shot(tester, 'insights-$suffix');
    });
  }
}

/// The shell's scaffold without the router: one screen and the nav bar.
class _Tab extends StatelessWidget {
  const _Tab({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: TraceNavBar(
      currentIndex: index,
      onSelect: (_) {},
      onPlus: () {},
    ),
  );
}

Future<void> _pump(WidgetTester tester, ThemeMode mode, Widget home) async {
  tester.view
    ..devicePixelRatio = _dpr
    ..physicalSize = _size * _dpr
    ..padding = const FakeViewPadding(top: 44 * _dpr, bottom: 20 * _dpr)
    ..viewPadding = const FakeViewPadding(top: 44 * _dpr, bottom: 20 * _dpr);
  // Every choreographed effect collapses to its end state, so each shot is the
  // screen at rest rather than a frame caught mid-cascade.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final db = AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  await tester.runAsync(() => _seed(db));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: TraceTheme.light(),
          darkTheme: TraceTheme.dark(),
          themeMode: mode,
          home: home,
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  await _settle(tester);
}

/// Long enough for every delayed fill and ticker to land.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('$_outDir/$name.png').writeAsBytes(png!.buffer.asUint8List());
  });
}

/// Tests draw text in a placeholder font unless the real ones are loaded.
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

// ── The record ──────────────────────────────────────────────────────────────

/// Eight weeks of a plausible life, ending today. Seeded, so reruns agree.
Future<void> _seed(AppDatabase db) async {
  final rnd = Random(7);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final t0 = today.subtract(const Duration(days: 90)).toUtc();
  String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  const projects = {
    'p-pds': ('PDS Express', 60 * 3600),
    'p-sakay': ('Libreng Sakay', 40 * 3600),
    'p-trace': ('TRACE', null),
    'p-nuxt': ('Nuxt CLI', null),
  };
  for (final MapEntry(key: id, value: (name, target)) in projects.entries) {
    await db.upsertProject(
      ProjectsCompanion.insert(
        id: id,
        name: name,
        targetSecs: Value(target),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
  }

  const books = [
    (
      'b-doet',
      'The Design of Everyday Things',
      'Don Norman',
      214,
      368,
      'reading',
    ),
    (
      'b-ddia',
      'Designing Data-Intensive Applications',
      'Martin Kleppmann',
      312,
      611,
      'reading',
    ),
    (
      'b-posd',
      'A Philosophy of Software Design',
      'John Ousterhout',
      190,
      190,
      'finished',
    ),
  ];
  for (final (id, title, author, page, total, status) in books) {
    await db.upsertBook(
      BooksCompanion.insert(
        id: id,
        title: title,
        author: Value(author),
        currentPage: Value(page),
        totalPages: Value(total),
        status: Value(status),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
  }

  var n = 0;
  Future<void> entry(
    DateTime day,
    String category,
    String title, {
    int? minutes,
    int? pages,
    String? project,
    String? book,
    required int at,
  }) {
    final created = day.add(Duration(minutes: at)).toUtc();
    return db.upsertEntry(
      EntriesCompanion.insert(
        id: 'e${n++}',
        category: category,
        title: title,
        date: key(day),
        durationSecs: Value(minutes == null ? null : minutes * 60),
        quantity: Value(pages?.toDouble()),
        quantityUnit: Value(pages == null ? null : 'pages'),
        projectId: Value(project),
        bookId: Value(book),
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  // Today, as the brief draws it. Newest first, so BUILD is written last.
  await entry(today, 'life', 'Walk', minutes: 28, at: 8 * 60);
  await entry(
    today,
    'explore',
    'Cloudflare Durable Objects',
    minutes: 41,
    at: 12 * 60,
  );
  await entry(
    today,
    'read',
    'The Design of Everyday Things',
    pages: 32,
    book: 'b-doet',
    at: 13 * 60,
  );
  await entry(
    today,
    'build',
    'PDS Express',
    minutes: 154,
    project: 'p-pds',
    at: 17 * 60,
  );
  await db.upsertNote(
    NotesCompanion.insert(
      id: 'n-today',
      body: 'Finally figured out the architecture.',
      kind: const Value('one_line'),
      date: Value(key(today)),
      createdAt: today.toUtc(),
      updatedAt: today.toUtc(),
    ),
  );
  await db.upsertNote(
    NotesCompanion.insert(
      id: 'n-doet',
      body:
          'Good design makes the relationship between user and object '
          'understandable.',
      kind: const Value('thought'),
      bookId: const Value('b-doet'),
      createdAt: today.toUtc(),
      updatedAt: today.toUtc(),
    ),
  );

  const topics = [
    'SQLite WAL mode',
    'How Discord stores trillions of messages',
    'Postgres row-level security',
    'CRDTs, again',
    'Neon branching',
    'Flutter Impeller internals',
    'Local-first software',
    'Why SQLite uses B-trees',
    'Rust ownership, from scratch',
    'The history of Unix pipes',
  ];
  const life = [
    ('Walk', 25, 50),
    ('Gym', 45, 75),
    ('Cooked dinner', 30, 60),
    ('Cleaned the apartment', 40, 80),
    ('Coffee with friends', 60, 120),
    ('Groceries', 20, 40),
  ];
  final build = [
    ...List.filled(9, 'p-pds'),
    ...List.filled(5, 'p-sakay'),
    ...List.filled(4, 'p-trace'),
    'p-nuxt',
  ];

  for (var back = 1; back <= 56; back++) {
    final day = today.subtract(Duration(days: back));
    // Some days simply aren't recorded. That's the point.
    if (rnd.nextDouble() < 0.12) continue;

    if (rnd.nextDouble() < 0.82) {
      final p = build[rnd.nextInt(build.length)];
      await entry(
        day,
        'build',
        projects[p]!.$1,
        minutes: 45 + rnd.nextInt(140),
        project: p,
        at: 20 * 60,
      );
    }
    if (rnd.nextDouble() < 0.7) {
      final b = back < 30 ? 'b-doet' : 'b-ddia';
      final title = books.firstWhere((x) => x.$1 == b).$2;
      await entry(
        day,
        'read',
        title,
        pages: 12 + rnd.nextInt(30),
        book: b,
        at: 22 * 60,
      );
    }
    if (rnd.nextDouble() < 0.72) {
      await entry(
        day,
        'explore',
        topics[rnd.nextInt(topics.length)],
        minutes: 15 + rnd.nextInt(60),
        at: 14 * 60,
      );
    }
    if (rnd.nextDouble() < 0.75) {
      final (title, lo, hi) = life[rnd.nextInt(life.length)];
      await entry(
        day,
        'life',
        title,
        minutes: lo + rnd.nextInt(hi - lo),
        at: 9 * 60,
      );
    }
  }
}
