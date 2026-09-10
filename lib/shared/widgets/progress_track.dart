import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The thin navy progress bar used by Presence, Projects and Reading.
///
/// Animates *from its previous value*, not from zero, so logging 27 pages reads
/// as movement along the bar rather than a redraw.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    this.height = TraceSize.track,
    this.animate = true,
  });

  /// 0.0 – 1.0. Values outside are clamped.
  final double value;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final target = value.clamp(0.0, 1.0);

    Widget bar(double v) => LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              Container(
                height: height,
                width: constraints.maxWidth * v,
                decoration: BoxDecoration(
                  color: c.navy,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          ),
        );

    if (!animate) return bar(target);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: TraceMotion.slow,
      curve: TraceMotion.standard,
      builder: (context, v, _) => bar(v),
    );
  }
}

/// A segmented progress bar — the blocky `████████░░` form from the Projects
/// mockup. Reads as a measured quantity rather than a smooth fill.
class SegmentedTrack extends StatelessWidget {
  const SegmentedTrack({
    super.key,
    required this.value,
    this.segments = 18,
    this.height = 6,
  });

  final double value;
  final int segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: TraceMotion.slow,
      curve: TraceMotion.standard,
      builder: (context, v, _) {
        final filled = (segments * v).round();
        return Row(
          children: List.generate(segments, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: i < filled ? c.navy : c.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
