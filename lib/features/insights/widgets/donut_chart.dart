import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/theme.dart';
import '../../../shared/widgets/entrance_tween.dart';
import '../../../shared/widgets/mono_duration.dart';

class DonutSlice {
  const DonutSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Time distribution, drawn rather than pulled from a charting library.
///
/// A dependency would bring its own palette, its own type, and its own idea of
/// what a chart should look like. This is ~100 lines and obeys the design system.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerBottom,
    this.centerSuffix = '',
    this.size = 128,
    this.thickness = 16,
    this.delay = Duration.zero,
  });

  final List<DonutSlice> slices;

  /// The total in the middle. Counts up while the arcs draw, so the number and
  /// the ring arrive as one reading.
  final int centerValue;
  final String centerSuffix;
  final String centerBottom;
  final double size;
  final double thickness;

  /// Holds the draw until the chart's section has faded in.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final total = slices.fold<double>(0, (s, e) => s + e.value);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EntranceTween<double>(
              begin: 0,
              end: 1,
              delay: delay,
              duration: const Duration(milliseconds: 900),
              curve: Curves.linear,
              builder: (context, t) => CustomPaint(
                painter: _DonutPainter(
                  slices: slices,
                  total: total,
                  progress: t,
                  thickness: thickness,
                  trackColor: c.border,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoValue(
                    centerValue,
                    suffix: centerSuffix,
                    style: TraceText.monoStat,
                    color: c.textPrimary,
                    delay: delay,
                  ),
                  Text(centerBottom,
                      style: TraceText.sectionLabel
                          .copyWith(color: c.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.progress,
    required this.thickness,
    required this.trackColor,
  });

  final List<DonutSlice> slices;
  final double total;
  final double progress;
  final double thickness;
  final Color trackColor;

  /// Share of the draw each arc spends sweeping; the rest is the stagger.
  /// Neighbouring arcs overlap in time, so the draw never stalls between them.
  static const _sweep = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (total <= 0) return;

    // Arcs resolve in sequence rather than all at once, so the chart reads as
    // being drawn instead of simply appearing. Each eases into its end, so the
    // pen slows as it reaches each boundary.
    var start = -math.pi / 2;
    final count = slices.length;

    for (var i = 0; i < count; i++) {
      final slice = slices[i];
      final sweep = (slice.value / total) * math.pi * 2;

      final begin = count <= 1 ? 0.0 : i / (count - 1) * (1 - _sweep);
      final local = ((progress - begin) / _sweep).clamp(0.0, 1.0);
      final eased = TraceMotion.emphasizedDecelerate.transform(local);

      if (eased > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep * eased,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.butt
            ..color = slice.color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.slices != slices ||
      old.trackColor != trackColor;
}
