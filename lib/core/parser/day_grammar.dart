/// A day named inside free text — "yesterday", "on monday" — and its span.
///
/// Relative, not absolute: the parser has no clock, so the match says how to
/// find the day and [resolve] does it against the day the caller supplies.
class DayMatch {
  const DayMatch.daysAgo(int this.daysAgo, {required this.start, required this.end})
      : weekday = null;

  const DayMatch.weekday(int this.weekday, {required this.start, required this.end})
      : daysAgo = null;

  final int? daysAgo;

  /// [DateTime.monday] … [DateTime.sunday].
  final int? weekday;

  final int start;
  final int end;

  /// The day meant, as local midnight.
  ///
  /// A weekday is always the most recent one *before* [today]: typing "on
  /// monday" on a Monday means last week, since today would be "today".
  DateTime resolve(DateTime today) {
    final base = DateTime(today.year, today.month, today.day);
    if (daysAgo != null) return DateTime(base.year, base.month, base.day - daysAgo!);
    final back = (base.weekday - weekday! + 7) % 7;
    return DateTime(base.year, base.month, base.day - (back == 0 ? 7 : back));
  }
}

/// Finds when something happened, so it can be logged the next morning.
///
/// Only the past: TRACE records what was done, not what is planned.
abstract final class DayGrammar {
  static const _numbers = {
    'a': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7,
  };

  static const _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  // Most specific first: "the day before yesterday" must win over "yesterday".
  static final _before = RegExp(r'\bthe day before yesterday\b', caseSensitive: false);
  static final _yesterday = RegExp(
    r'\b(?:yesterday(?:\s+(?:morning|afternoon|evening|night))?|last night)\b',
    caseSensitive: false,
  );
  static final _ago = RegExp(
    r'\b(\d+|a|one|two|three|four|five|six|seven)\s+days?\s+ago\b',
    caseSensitive: false,
  );
  static final _weekday = RegExp(
    r'\b(?:on|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    caseSensitive: false,
  );
  static final _today = RegExp(
    r'\b(?:today|tonight|this (?:morning|afternoon|evening))\b',
    caseSensitive: false,
  );

  static DayMatch? find(String input) {
    RegExpMatch? m;
    if ((m = _before.firstMatch(input)) != null) {
      return DayMatch.daysAgo(2, start: m!.start, end: m.end);
    }
    if ((m = _yesterday.firstMatch(input)) != null) {
      return DayMatch.daysAgo(1, start: m!.start, end: m.end);
    }
    if ((m = _ago.firstMatch(input)) != null) {
      final word = m!.group(1)!.toLowerCase();
      final n = int.tryParse(word) ?? _numbers[word]!;
      return DayMatch.daysAgo(n, start: m.start, end: m.end);
    }
    if ((m = _weekday.firstMatch(input)) != null) {
      return DayMatch.weekday(
        _weekdays[m!.group(1)!.toLowerCase()]!,
        start: m.start,
        end: m.end,
      );
    }
    if ((m = _today.firstMatch(input)) != null) {
      return DayMatch.daysAgo(0, start: m!.start, end: m.end);
    }
    return null;
  }
}
