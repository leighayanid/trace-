import 'package:flutter/material.dart';

import '../../../app/theme/theme.dart';
import '../../../shared/widgets/entrance_tween.dart';

/// One category's month: a filled dot for a day present, hollow for absent.
///
/// Dots ripple in left to right, each growing out of a point as it fades up,
/// which reads as the month being written out. Absence is drawn as an empty
/// ring, never as a warning — a missed day is a fact about the record, not a
/// failure.
class ConsistencyRow extends StatelessWidget {
  const ConsistencyRow({
    super.key,
    required this.label,
    required this.days,
    this.delay = Duration.zero,
  });

  final String label;

  /// One bool per day of the month.
  final List<bool> days;

  /// Holds the ripple until the row itself has faded in.
  final Duration delay;

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
            // Isolated so ~30 dots animating does not repaint the scroll view
            // around them.
            child: RepaintBoundary(
              child: EntranceTween<double>(
                begin: 0,
                end: 1,
                delay: delay,
                // Long enough that a 31-day row reads as a sweep, not a flash:
                // each dot starts [TraceMotion.dotStagger] after the last.
                // Capped at a month's worth, so a year's row sweeps as fast.
                duration: TraceMotion.dotStagger * days.length.clamp(1, 31) +
                    const Duration(milliseconds: 260),
                curve: Curves.linear,
                builder: (context, t) => _Dots(
                  days: days,
                  progress: t,
                  filled: c.navy,
                  empty: c.border,
                ),
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

  /// Share of the sweep each dot spends growing in; the rest is the stagger.
  static const _grow = 0.3;

  @override
  Widget build(BuildContext context) {
    final n = days.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++)
          Expanded(
            child: Center(
              child: _dot(
                i,
                ((progress - (n <= 1 ? 0.0 : i / (n - 1) * (1 - _grow))) /
                        _grow)
                    .clamp(0.0, 1.0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(int i, double t) {
    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: 0.3 + 0.7 * TraceMotion.emphasizedDecelerate.transform(t),
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
    );
  }
}
