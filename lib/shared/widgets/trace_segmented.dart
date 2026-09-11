import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// A small set of mutually exclusive choices, shown all at once.
///
/// A navy-light track with the selected segment filled navy. Used wherever a
/// choice is short enough that a picker sheet would be more UI than the choice
/// itself.
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

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.navyLight,
        borderRadius: BorderRadius.circular(TraceRadius.button),
      ),
      child: Row(
        children: [
          for (final MapEntry(key: value, value: label) in segments.entries)
            Expanded(
              child: PressScale(
                onTap: () => onSelect(value),
                child: AnimatedContainer(
                  duration: TraceMotion.fast,
                  curve: TraceMotion.standard,
                  padding: const EdgeInsets.symmetric(vertical: TraceSpace.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? c.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(TraceRadius.button - 2),
                  ),
                  child: Text(
                    label,
                    style: TraceText.rowSubtitle.copyWith(
                      color: value == selected ? c.onNavy : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
