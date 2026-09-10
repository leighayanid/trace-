import 'package:flutter/material.dart';

import '../../../app/theme/theme.dart';

/// One category's month: a filled dot for a day present, hollow for absent.
///
/// Dots ripple in left to right, which reads as the month being written out.
/// Absence is drawn as an empty ring, never as a warning — a missed day is a
/// fact about the record, not a failure.
class ConsistencyRow extends StatelessWidget {
  const ConsistencyRow({
    super.key,
    required this.label,
    required this.days,
  });

  final String label;

  /// One bool per day of the month.
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final present = days.where((d) => d).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TraceSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(label,
                style: TraceText.rowSubtitle.copyWith(color: c.textPrimary)),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: TraceMotion.slow,
              curve: Curves.linear,
              builder: (context, t, _) => _Dots(
                days: days,
                progress: t,
                filled: c.navy,
                empty: c.border,
              ),
            ),
          ),
          const SizedBox(width: TraceSpace.md),
          // "16 days", never a streak. Missing a day must not read as a break.
          Text('$present days',
              style: TraceText.monoSmall.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.days,
    required this.progress,
    required this.filled,
    required this.empty,
  });

  final List<bool> days;
  final double progress;
  final Color filled;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    final revealed = (days.length * progress).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Center(
              child: AnimatedOpacity(
                opacity: i < revealed ? 1 : 0,
                duration: TraceMotion.fast,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: days[i] ? filled : Colors.transparent,
                    border: days[i] ? null : Border.all(color: empty),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
