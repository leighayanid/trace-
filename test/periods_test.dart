import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/insights/insights_providers.dart';
import 'package:trace/shared/widgets/day_picker.dart';

/// Naming days, and stepping Insights back through months and years.
void main() {
  // The current-day provider listens for the app resuming.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dayLabel', () {
    final today = DateTime(2026, 9, 18); // a Friday

    test('names the last week by relation, then by date', () {
      expect(dayLabel(today, today), 'Today');
      expect(dayLabel(DateTime(2026, 9, 17), today), 'Yesterday');
      expect(dayLabel(DateTime(2026, 9, 14), today), 'Monday');
      expect(dayLabel(DateTime(2026, 9, 9), today), 'Wed, Sep 9');
    });

    test('adds the year only when it is not this one', () {
      expect(dayLabel(DateTime(2025, 12, 31), today), 'Wed, Dec 31, 2025');
    });

    test('ignores the time of day', () {
      expect(dayLabel(DateTime(2026, 9, 17, 23, 59), DateTime(2026, 9, 18, 0, 1)),
          'Yesterday');
    });
  });

  group('InsightsPeriod', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    final now = DateTime.now();
    InsightsPeriod period() => container.read(insightsPeriodProvider.notifier);
    DateTime start() => container.read(insightsPeriodProvider);

    test('starts at this month, and cannot step into the future', () {
      expect(start(), DateTime(now.year, now.month));
      expect(period().isCurrent, isTrue);

      period().next();
      expect(start(), DateTime(now.year, now.month));
    });

    test('steps back a month at a time, across the year boundary', () {
      for (var i = 0; i < now.month; i++) {
        period().previous();
      }
      expect(start(), DateTime(now.year - 1, 12));
      expect(period().isCurrent, isFalse);
      expect(period().direction, -1);

      period().next();
      expect(start(), DateTime(now.year, 1));
      expect(period().direction, 1);
    });

    test('changing the range returns to the present', () {
      period().previous();
      container
          .read(insightsRangeProvider.notifier)
          .select(InsightsRange.year);

      expect(start(), DateTime(now.year));
      period().previous();
      expect(start(), DateTime(now.year - 1));
    });
  });
}
