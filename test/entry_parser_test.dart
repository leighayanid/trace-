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
}
