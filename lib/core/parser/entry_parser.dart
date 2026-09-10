import '../../shared/models/category.dart';
import 'duration_grammar.dart';
import 'quantity_grammar.dart';

/// The structured result of reading a sentence the user typed.
///
/// Every field is a *proposal*. The confirmation screen lets all of them be
/// edited before saving — the parser suggests, it never decides.
class ParsedEntry {
  const ParsedEntry({
    required this.raw,
    required this.category,
    required this.title,
    this.duration,
    this.quantity,
    this.quantityUnit,
    this.projectId,
    this.bookId,
    this.matchedCategory = false,
  });

  final String raw;
  final Category category;
  final String title;
  final Duration? duration;
  final double? quantity;
  final String? quantityUnit;
  final String? projectId;
  final String? bookId;

  /// False when the category fell back to a default rather than being
  /// recognised — the UI uses this to draw attention to the category field.
  final bool matchedCategory;

  ParsedEntry copyWith({
    Category? category,
    String? title,
    Duration? duration,
    double? quantity,
    String? quantityUnit,
    String? projectId,
    String? bookId,
  }) {
    return ParsedEntry(
      raw: raw,
      category: category ?? this.category,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      projectId: projectId ?? this.projectId,
      bookId: bookId ?? this.bookId,
      matchedCategory: matchedCategory,
    );
  }
}

/// A name the parser can match against — a known project or book.
class NamedRef {
  const NamedRef(this.id, this.name);
  final String id;
  final String name;
}

/// Turns "coded for 2 hours on PDS Express" into structured data, on-device.
///
/// Deliberately rule-based rather than model-backed: it runs offline, returns
/// instantly, and behaves the same way every time. A wrong guess the user must
/// correct twice is worse than a blank field.
class EntryParser {
  const EntryParser({
    this.projects = const [],
    this.books = const [],
  });

  final List<NamedRef> projects;
  final List<NamedRef> books;

  static const _keywords = <Category, List<String>>{
    Category.build: [
      'code', 'coded', 'coding', 'built', 'build', 'building', 'wrote',
      'writing', 'implemented', 'implement', 'fixed', 'fixing', 'debugged',
      'debugging', 'refactored', 'refactor', 'designed', 'designing',
      'shipped', 'deployed', 'worked on', 'working on', 'programmed',
    ],
    Category.read: [
      'read', 'reading', 'finished reading', 'book', 'chapter', 'pages',
      'page', 'paper', 'essay', 'article',
    ],
    Category.explore: [
      'browsed', 'browsing', 'explored', 'exploring', 'researched',
      'researching', 'looked into', 'looking into', 'learned about',
      'learning about', 'watched', 'watching', 'rabbit hole', 'docs',
      'documentation', 'googled',
    ],
    Category.life: [
      'walk', 'walked', 'walking', 'ran', 'run', 'running', 'gym', 'workout',
      'exercised', 'slept', 'sleep', 'nap', 'ate', 'eating', 'cooked',
      'cleaned', 'cleaning', 'errand', 'errands', 'rested', 'rest', 'groceries',
      'shower', 'drove', 'commute',
    ],
  };

  /// Verbs and fillers stripped from the front of a title.
  static final _leadingNoise = RegExp(
    r'^(?:i\s+)?(?:just\s+)?(?:spent\s+|did\s+|was\s+)?'
    r'(?:coded?|coding|built|building|wrote|writing|read(?:ing)?|browsed?|'
    r'browsing|explored?|exploring|researched?|researching|watched?|watching|'
    r'worked|working|walked?|walking|ran|running|slept|sleeping|studied|'
    r'studying|learned|learning)\s*',
    caseSensitive: false,
  );

  /// Connectives that introduce the subject: "on X", "of X", "about X".
  static final _subjectLead = RegExp(
    r'^(?:for\s+|on\s+|of\s+|about\s+|through\s+|into\s+|at\s+|in\s+|to\s+|the\s+)+',
    caseSensitive: false,
  );

  ParsedEntry parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return ParsedEntry(
        raw: raw,
        category: Category.build,
        title: '',
        matchedCategory: false,
      );
    }

    final lower = raw.toLowerCase();

    // Cut the measured spans out before deriving a title, so "2 hours" never
    // ends up inside the entry name.
    final durationMatch = DurationGrammar.find(raw);
    final quantityMatch = QuantityGrammar.find(raw);

    final spans = <({int start, int end})>[
      if (durationMatch != null)
        (start: durationMatch.start, end: durationMatch.end),
      if (quantityMatch != null)
        (start: quantityMatch.start, end: quantityMatch.end),
    ]..sort((a, b) => b.start.compareTo(a.start));

    var remainder = raw;
    for (final s in spans) {
      remainder = remainder.replaceRange(s.start, s.end, ' ');
    }

    final (category, matched) = _category(lower, quantityMatch);
    final project = _match(projects, lower);
    final book = _match(books, lower);

    return ParsedEntry(
      raw: raw,
      category: category,
      title: _title(remainder, project, book),
      duration: durationMatch?.duration,
      quantity: quantityMatch?.value,
      quantityUnit: quantityMatch?.unit,
      projectId: category == Category.build ? project?.id : null,
      bookId: category == Category.read ? book?.id : null,
      matchedCategory: matched,
    );
  }

  (Category, bool) _category(String lower, QuantityMatch? quantity) {
    // "27 pages" is decisive on its own — no verb needed.
    if (quantity?.unit == 'pages') return (Category.read, true);

    var best = Category.build;
    var bestScore = 0;

    for (final entry in _keywords.entries) {
      var score = 0;
      for (final word in entry.value) {
        if (RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower)) {
          // Longer phrases are more specific than single verbs.
          score += word.contains(' ') ? 3 : 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }

    return (best, bestScore > 0);
  }

  NamedRef? _match(List<NamedRef> refs, String lower) {
    final squashed = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    NamedRef? best;
    var bestLen = 0;

    for (final ref in refs) {
      final name = ref.name.toLowerCase();
      final refSquashed = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (refSquashed.isEmpty) continue;

      final hit = lower.contains(name) || squashed.contains(refSquashed);
      // Longest match wins, so "TRACE CLI" beats "TRACE".
      if (hit && refSquashed.length > bestLen) {
        best = ref;
        bestLen = refSquashed.length;
      }
    }
    return best;
  }

  String _title(String remainder, NamedRef? project, NamedRef? book) {
    // A recognised name is always a better title than a scrubbed sentence.
    if (project != null) return project.name;
    if (book != null) return book.name;

    var text = remainder.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceFirst(_leadingNoise, '');
    text = text.replaceFirst(_subjectLead, '');
    text = text.replaceAll(RegExp(r'^[\s,\-–—]+|[\s,\-–—]+$'), '').trim();

    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}
