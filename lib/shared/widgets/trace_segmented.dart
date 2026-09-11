import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// A small set of mutually exclusive choices, shown all at once.
///
/// A navy-light track with a navy thumb that *slides* to the selected segment
/// rather than jumping — the thumb is one object that moves, not one colour
/// switching off as another switches on. Used wherever a choice is short enough
/// that a picker sheet would be more UI than the choice itself.
class TraceSegmented<T> extends StatelessWidget {
  const TraceSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
  });

  /// Value → label, in display order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final values = segments.keys.toList();
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final n = values.length;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.navyLight,
        borderRadius: BorderRadius.circular(TraceRadius.button),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              duration: const Duration(milliseconds: 420),
              curve: TraceMotion.emphasized,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.navy,
                    borderRadius: BorderRadius.circular(TraceRadius.button - 2),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final MapEntry(key: value, value: label) in segments.entries)
                Expanded(
                  child: PressScale(
                    onTap: () {
                      if (value == selected) return;
                      HapticFeedback.selectionClick();
                      onSelect(value);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: TraceSpace.sm,
                      ),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: TraceMotion.base,
                          curve: TraceMotion.standard,
                          style: TraceText.rowSubtitle.copyWith(
                            color:
                                value == selected ? c.onNavy : c.textSecondary,
                          ),
                          child: Text(label),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
