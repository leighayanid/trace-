import '../../shared/models/category.dart';
import 'day_grammar.dart';
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
    this.day,
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

  /// When it happened, if the sentence said — "yesterday", "on monday". Null
  /// means it did not say, and the caller decides.
  final DayMatch? day;

  /// False when the category fell back to a default rather than being
  /// recognised — the UI uses this to draw attention to the category field.
  final bool matchedCategory;
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
    final dayMatch = DayGrammar.find(raw);

    final spans = <({int start, int end})>[
      if (durationMatch != null)
        (start: durationMatch.start, end: durationMatch.end),
      if (quantityMatch != null)
        (start: quantityMatch.start, end: quantityMatch.end),
      if (dayMatch != null) (start: dayMatch.start, end: dayMatch.end),
    ]..sort((a, b) => b.start.compareTo(a.start));

    var remainder = raw;
    var floor = raw.length;
    for (final s in spans) {
      // Right to left, so earlier offsets stay valid. An overlapping span was
      // already cut by its neighbour.
      if (s.end > floor) continue;
      remainder = remainder.replaceRange(s.start, s.end, ' ');
      floor = s.start;
    }

    final words = _words(raw);
    final project = _match(projects, words);
    final book = _match(books, words);
    final (category, matched) =
        _category(lower, quantityMatch, project: project, book: book);

    // A project belongs to BUILD and a book to READ. Outside those, a name
    // that happens to appear is just words in the sentence.
    final ownProject = category == Category.build ? project : null;
    final ownBook = category == Category.read ? book : null;

    return ParsedEntry(
      raw: raw,
      category: category,
      title: _title(remainder, ownProject, ownBook),
      duration: durationMatch?.duration,
      quantity: quantityMatch?.value,
      quantityUnit: quantityMatch?.unit,
      projectId: ownProject?.id,
      bookId: ownBook?.id,
      day: dayMatch,
      matchedCategory: matched,
    );
  }

  (Category, bool) _category(
    String lower,
    QuantityMatch? quantity, {
    NamedRef? project,
    NamedRef? book,
  }) {
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

    if (bestScore > 0) return (best, true);

    // No verb, but a name the user gave a project or a book is as good as one:
    // "2h on TRACE" is building, "Atomic Habits 20m" is reading.
    if (project != null) return (Category.build, true);
    if (book != null) return (Category.read, true);
    return (best, false);
  }

  static final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _words(String s) =>
      s.toLowerCase().split(_separators).where((w) => w.isNotEmpty).toList();

  /// The ref whose name appears in [words] as whole words.
  ///
  /// Spacing and punctuation are ignored — "pds express", "PDS-Express" and
  /// "pdsexpress" all find PDS Express — but a name never matches inside a
  /// word, so a project called "Art" is not found in "started".
  NamedRef? _match(List<NamedRef> refs, List<String> words) {
    NamedRef? best;
    var bestLen = 0;

    for (final ref in refs) {
      final target = _words(ref.name).join();
      // Longest match wins, so "TRACE CLI" beats "TRACE".
      if (target.isEmpty || target.length <= bestLen) continue;
      if (_runOf(words, target)) {
        best = ref;
        bestLen = target.length;
      }
    }
    return best;
  }

  /// Whether some run of consecutive [words], joined, spells [target].
  static bool _runOf(List<String> words, String target) {
    for (var i = 0; i < words.length; i++) {
      var joined = '';
      for (var j = i; j < words.length && joined.length < target.length; j++) {
        joined += words[j];
        if (joined == target) return true;
      }
    }
    return false;
  }

  String _title(String remainder, NamedRef? project, NamedRef? book) {
    // A recognised name is always a better title than a scrubbed sentence.
    if (project != null) return project.name;
    if (book != null) return book.name;

    final whole = remainder.replaceAll(RegExp(r'\s+'), ' ').trim();
    var text = whole.replaceFirst(_leadingNoise, '');
    text = text.replaceFirst(_subjectLead, '');
    text = _clean(text);

    // "walked yesterday" leaves nothing once the verb is taken as noise. The
    // verb is then the best title there is — better than the raw sentence
    // with its "yesterday" still in it.
    if (text.isEmpty) text = _clean(whole);

    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Trims stray punctuation, and connectives stranded at the end once a span
  /// is cut — "durable objects for", from "durable objects for 40m".
  static String _clean(String s) => s
      .replaceFirst(_trailingLead, '')
      .replaceAll(RegExp(r'^[\s,\-–—]+|[\s,\-–—]+$'), '')
      .trim();

  static final _trailingLead = RegExp(
    r'(?:(?:^|\s+)(?:for|on|of|about|through|into|at|in|to|the))+\s*$',
    caseSensitive: false,
  );
}
