/// A counted quantity found inside free text, and the span it occupied.
class QuantityMatch {
  const QuantityMatch({
    required this.value,
    required this.unit,
    required this.start,
    required this.end,
  });

  final double value;

  /// pages | km | sessions | items
  final String unit;
  final int start;
  final int end;
}

/// Extracts "27 pages", "3.2 km", "2 chapters" and friends.
///
/// Kept separate from duration because an entry may carry a quantity, a
/// duration, both, or neither — they are not alternatives to each other.
abstract final class QuantityGrammar {
  static final _units = <RegExp, String>{
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:pages?|pp?\.?)\b', caseSensitive: false):
        'pages',
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:km|kilometers?|kilometres?)\b',
        caseSensitive: false): 'km',
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:miles?|mi)\b', caseSensitive: false): 'km',
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:chapters?)\b', caseSensitive: false):
        'items',
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:sessions?|sets?|reps?)\b',
        caseSensitive: false): 'sessions',
  };

  /// Miles are converted to km so distance stays in one unit.
  static const _mileToKm = 1.609344;

  static QuantityMatch? find(String input) {
    for (final entry in _units.entries) {
      final m = entry.key.firstMatch(input);
      if (m == null) continue;

      var value = double.parse(m.group(1)!);
      final isMiles = m.group(0)!.toLowerCase().contains('mi');
      if (entry.value == 'km' && isMiles) {
        value = double.parse((value * _mileToKm).toStringAsFixed(2));
      }

      return QuantityMatch(
        value: value,
        unit: entry.value,
        start: m.start,
        end: m.end,
      );
    }
    return null;
  }

  /// `27 pages`, `3.2 km` — the display form used on entry rows.
  static String format(double value, String unit) {
    final n = value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
    if (unit == 'pages') return '$n ${value == 1 ? 'page' : 'pages'}';
    return '$n $unit';
  }
}
