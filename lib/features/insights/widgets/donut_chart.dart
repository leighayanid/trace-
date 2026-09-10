import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/theme.dart';

class DonutSlice {
  const DonutSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Time distribution, drawn rather than pulled from a charting library.
///
/// A dependency would bring its own palette, its own type, and its own idea of
/// what a chart should look like. This is ~90 lines and obeys the design system.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerTop,
    required this.centerBottom,
    this.size = 128,
    this.thickness = 16,
  });

  final List<DonutSlice> slices;
  final String centerTop;
  final String centerBottom;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final total = slices.fold<double>(0, (s, e) => s + e.value);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: TraceMotion.slow,
          curve: TraceMotion.standard,
          builder: (context, t, _) => CustomPaint(
            painter: _DonutPainter(
              slices: slices,
              total: total,
              progress: t,
              thickness: thickness,
              trackColor: c.border,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerTop,
                      style:
                          TraceText.monoStat.copyWith(color: c.textPrimary)),
                  Text(centerBottom,
                      style: TraceText.sectionLabel
                          .copyWith(color: c.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          ),
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
    // being drawn instead of simply appearing.
    var start = -math.pi / 2;
    final count = slices.length;

    for (var i = 0; i < count; i++) {
      final slice = slices[i];
      final sweep = (slice.value / total) * math.pi * 2;

      final begin = i / count;
      final end = (i + 1) / count;
      final local =
          ((progress - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();

      if (local > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep * local,
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
      old.progress != progress || old.slices != slices;
}
