/// A duration found inside free text, and the span it occupied.
class DurationMatch {
  const DurationMatch({
    required this.duration,
    required this.start,
    required this.end,
  });

  final Duration duration;
  final int start;
  final int end;
}

/// Deterministic duration extraction. No network, no model, works offline.
///
/// Patterns are ordered most-specific first, because `1h30` must win before the
/// bare-hours rule claims the `1h` and leaves `30` behind as a stray number.
abstract final class DurationGrammar {
  static final _patterns = <RegExp>[
    // 1h30, 2h05
    RegExp(r'(\d+)\s*h\s*(\d{1,2})\b', caseSensitive: false),
    // 2.5 hours, 2 hrs, 3h
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b',
        caseSensitive: false),
    // 45 minutes, 30 mins, 20m
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|min|mins|minute|minutes)\b',
        caseSensitive: false),
  ];

  static final _phrases = <RegExp, Duration>{
    RegExp(r'\bhalf an hour\b', caseSensitive: false):
        const Duration(minutes: 30),
    RegExp(r'\ban hour and a half\b', caseSensitive: false):
        const Duration(minutes: 90),
    RegExp(r'\ban hour\b', caseSensitive: false): const Duration(hours: 1),
    RegExp(r'\ba couple of hours\b', caseSensitive: false):
        const Duration(hours: 2),
    RegExp(r'\ball morning\b', caseSensitive: false): const Duration(hours: 3),
    RegExp(r'\ball afternoon\b', caseSensitive: false): const Duration(hours: 4),
  };

  /// Returns the first duration in [input], or null.
  static DurationMatch? find(String input) {
    for (final entry in _phrases.entries) {
      final m = entry.key.firstMatch(input);
      if (m != null) {
        return DurationMatch(
          duration: entry.value,
          start: m.start,
          end: m.end,
        );
      }
    }

    for (var i = 0; i < _patterns.length; i++) {
      final m = _patterns[i].firstMatch(input);
      if (m == null) continue;

      final Duration d;
      switch (i) {
        case 0:
          d = Duration(
            hours: int.parse(m.group(1)!),
            minutes: int.parse(m.group(2)!),
          );
        case 1:
          d = Duration(
            milliseconds:
                (double.parse(m.group(1)!) * Duration.millisecondsPerHour)
                    .round(),
          );
        default:
          d = Duration(
            milliseconds:
                (double.parse(m.group(1)!) * Duration.millisecondsPerMinute)
                    .round(),
          );
      }
      return DurationMatch(duration: d, start: m.start, end: m.end);
    }
    return null;
  }
}
