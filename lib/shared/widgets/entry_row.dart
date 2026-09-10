import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../models/category.dart';
import 'category_glyph.dart';
import 'mono_duration.dart';
import 'press_scale.dart';

/// The single most reused widget in TRACE — Today and Timeline both render
/// entries with it, so it is built once and shared.
///
/// Layout: glyph tile · category caps over subtitle · mono value · chevron.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.category,
    required this.title,
    this.duration,
    this.quantityLabel,
    this.onTap,
    this.heroTag,
    this.showChevron = true,
    this.animateValue = true,
  });

  final Category category;

  /// The subtitle line — the project, book or activity name.
  final String title;

  /// Rendered as `02:34`. Mutually exclusive with [quantityLabel].
  final Duration? duration;

  /// Pre-formatted alternative for non-time entries, e.g. `32 pages`.
  ///
  /// An entry may use duration, quantity, or neither — nothing is forced into a
  /// time value.
  final String? quantityLabel;

  final VoidCallback? onTap;
  final Object? heroTag;
  final bool showChevron;
  final bool animateValue;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TraceSpace.rowY),
        child: Row(
          children: [
            CategoryGlyph(category: category, heroTag: heroTag),
            const SizedBox(width: TraceSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.label,
                    style:
                        TraceText.categoryLabel.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TraceText.rowSubtitle.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TraceSpace.sm),
            _value(context),
            if (showChevron) ...[
              const SizedBox(width: TraceSpace.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: c.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _value(BuildContext context) {
    final c = context.traceColors;
    if (quantityLabel != null) {
      return Text(
        quantityLabel!,
        style: TraceText.mono.copyWith(color: c.textPrimary),
      );
    }
    if (duration != null) {
      return MonoDuration(duration!, animate: animateValue);
    }
    return const SizedBox.shrink();
  }
}
