import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/parser/entry_parser.dart';
import 'package:trace/core/parser/duration_grammar.dart';
import 'package:trace/core/parser/quantity_grammar.dart';
import 'package:trace/shared/models/category.dart';

void main() {
  const projects = [
    NamedRef('p1', 'PDS Express'),
    NamedRef('p2', 'Libreng Sakay'),
    NamedRef('p3', 'TRACE'),
  ];
  const books = [
    NamedRef('b1', 'Atomic Habits'),
    NamedRef('b2', 'The Design of Everyday Things'),
  ];
  const parser = EntryParser(projects: projects, books: books);

  group('DurationGrammar', () {
    test('parses compound hour+minute before bare hours', () {
      // The ordering trap: a bare-hours rule would claim "1h" and strand "30".
      expect(DurationGrammar.find('1h30')!.duration,
          const Duration(hours: 1, minutes: 30));
    });

    test('parses hours in several spellings', () {
      for (final s in ['2 hours', '2h', '2 hrs', '2hr']) {
        expect(DurationGrammar.find(s)!.duration, const Duration(hours: 2),
            reason: s);
      }
    });

    test('parses fractional hours', () {
      expect(DurationGrammar.find('2.5 hours')!.duration,
          const Duration(hours: 2, minutes: 30));
    });

    test('parses minutes', () {
      for (final s in ['45 minutes', '45 mins', '45m']) {
        expect(DurationGrammar.find(s)!.duration, const Duration(minutes: 45),
            reason: s);
      }
    });

    test('parses natural phrases', () {
      expect(DurationGrammar.find('half an hour')!.duration,
          const Duration(minutes: 30));
      expect(DurationGrammar.find('an hour')!.duration,
          const Duration(hours: 1));
    });

    test('returns null when there is no duration', () {
      expect(DurationGrammar.find('went for a walk'), isNull);
    });
  });

  group('QuantityGrammar', () {
    test('parses pages', () {
      final m = QuantityGrammar.find('read 27 pages')!;
      expect(m.value, 27);
      expect(m.unit, 'pages');
    });

    test('converts miles to km', () {
      final m = QuantityGrammar.find('ran 2 miles')!;
      expect(m.unit, 'km');
      expect(m.value, closeTo(3.22, 0.01));
    });

    test('formats singular and plural pages', () {
      expect(QuantityGrammar.format(1, 'pages'), '1 page');
      expect(QuantityGrammar.format(27, 'pages'), '27 pages');
    });
  });

  group('EntryParser — the CLAUDE.md examples', () {
    test('"coded for 2 hours on PDS Express"', () {
      final r = parser.parse('coded for 2 hours on PDS Express');
      expect(r.category, Category.build);
      expect(r.title, 'PDS Express');
      expect(r.duration, const Duration(hours: 2));
      expect(r.projectId, 'p1');
    });

    test('"read 27 pages of Atomic Habits"', () {
      final r = parser.parse('read 27 pages of Atomic Habits');
      expect(r.category, Category.read);
      expect(r.title, 'Atomic Habits');
      expect(r.quantity, 27);
      expect(r.quantityUnit, 'pages');
      expect(r.bookId, 'b1');
    });

    test('"coded for 2 hours on TRACE"', () {
      final r = parser.parse('coded for 2 hours on TRACE');
      expect(r.category, Category.build);
      expect(r.title, 'TRACE');
      expect(r.duration, const Duration(hours: 2));
    });
  });

  group('EntryParser — categories', () {
    test('detects explore', () {
      final r = parser.parse('browsed cloudflare durable objects docs for 41m');
      expect(r.category, Category.explore);
      expect(r.duration, const Duration(minutes: 41));
    });

    test('detects life', () {
      final r = parser.parse('went for a walk for 28 minutes');
      expect(r.category, Category.life);
      expect(r.duration, const Duration(minutes: 28));
    });

    test('page count alone implies reading, with no verb', () {
      final r = parser.parse('32 pages');
      expect(r.category, Category.read);
      expect(r.matchedCategory, isTrue);
    });

    test('flags an unrecognised category rather than guessing silently', () {
      final r = parser.parse('zzzz qqqq');
      expect(r.matchedCategory, isFalse);
    });
  });

  group('EntryParser — titles', () {
    test('strips the measured span out of the title', () {
      final r = parser.parse('coded for 2 hours on some new thing');
      expect(r.title, isNot(contains('2')));
      expect(r.title, isNot(contains('hour')));
    });

    test('prefers the longest matching project name', () {
      final r = parser.parse('worked on Libreng Sakay for 1h');
      expect(r.projectId, 'p2');
      expect(r.title, 'Libreng Sakay');
    });

    test('capitalises a derived title', () {
      final r = parser.parse('explored distributed systems for 20m');
      expect(r.title, startsWith('D'));
    });

    test('handles empty input without throwing', () {
      final r = parser.parse('   ');
      expect(r.title, isEmpty);
      expect(r.duration, isNull);
    });

    test('an entry may have neither duration nor quantity', () {
      final r = parser.parse('walked');
      expect(r.duration, isNull);
      expect(r.quantity, isNull);
      expect(r.category, Category.life);
    });
  });

  group('EntryParser — which day', () {
    // A Friday.
    final today = DateTime(2026, 9, 18);
    DateTime? dayOf(String input) => parser.parse(input).day?.resolve(today);

    test('says nothing when the sentence does not', () {
      expect(parser.parse('walked for 30m').day, isNull);
    });

    test('yesterday and last night', () {
      expect(dayOf('walked yesterday'), DateTime(2026, 9, 17));
      expect(dayOf('slept 8 hours last night'), DateTime(2026, 9, 17));
      expect(dayOf('read yesterday evening'), DateTime(2026, 9, 17));
    });

    test('the day before yesterday wins over yesterday', () {
      expect(dayOf('coded the day before yesterday'), DateTime(2026, 9, 16));
    });

    test('days ago, in digits or words', () {
      expect(dayOf('ran 5 km 3 days ago'), DateTime(2026, 9, 15));
      expect(dayOf('walked two days ago'), DateTime(2026, 9, 16));
    });

    test('a weekday is the most recent one before today', () {
      expect(dayOf('coded on monday'), DateTime(2026, 9, 14));
      // Today is Friday, so "on friday" means last week's.
      expect(dayOf('walked last friday'), DateTime(2026, 9, 11));
    });

    test('"today" and "this morning" are today', () {
      expect(dayOf('coded today'), today);
      expect(dayOf('walked this morning'), today);
    });

    test('crosses a month boundary', () {
      final first = DateTime(2026, 10, 1);
      expect(parser.parse('walked yesterday').day!.resolve(first),
          DateTime(2026, 9, 30));
    });

    test('the day is cut out of the title', () {
      final r = parser.parse('explored durable objects yesterday for 40m');
      expect(r.title, 'Durable objects');
    });

    test('a bare verb becomes the title rather than the raw sentence', () {
      expect(parser.parse('walked yesterday').title, 'Walked');
      expect(parser.parse('walked for 30m').title, 'Walked');
    });
  });

  group('EntryParser — names', () {
    test('a name never matches inside another word', () {
      const p = EntryParser(projects: [NamedRef('p9', 'Art')]);
      final r = p.parse('started coding for 2h');
      expect(r.projectId, isNull);
    });

    test('spacing and punctuation in a name are forgiven', () {
      for (final s in [
        'coded on pdsexpress for 1h',
        'coded on PDS-Express for 1h',
        'coded on pds  express for 1h',
      ]) {
        expect(parser.parse(s).projectId, 'p1', reason: s);
      }
    });

    test('a known name is enough to set the category', () {
      final build = parser.parse('2h on TRACE');
      expect(build.category, Category.build);
      expect(build.matchedCategory, isTrue);
      expect(build.projectId, 'p3');

      final read = parser.parse('Atomic Habits 20m');
      expect(read.category, Category.read);
      expect(read.bookId, 'b1');
    });

    test('a project named in a LIFE sentence is not its title', () {
      final r = parser.parse('walked to the TRACE meetup');
      expect(r.category, Category.life);
      expect(r.projectId, isNull);
      expect(r.title, isNot('TRACE'));
    });
  });
}
