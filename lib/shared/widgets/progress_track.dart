import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'entrance_tween.dart';

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
    this.delay = Duration.zero,
  });

  /// 0.0 – 1.0. Values outside are clamped.
  final double value;
  final double height;
  final bool animate;

  /// Holds the first fill until the bar's section has faded in.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return EntranceTween<double>(
      begin: 0,
      end: value.clamp(0.0, 1.0),
      delay: delay,
      duration: const Duration(milliseconds: 900),
      curve: TraceMotion.emphasizedDecelerate,
      animate: animate,
      // Full width even under loose constraints — a start-aligned Column would
      // otherwise shrink the painter to nothing.
      builder: (context, v) => SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _TrackPainter(value: v, track: c.border, fill: c.navy),
        ),
      ),
    );
  }
}

/// Painted rather than composed from two Containers: the fill is redrawn every
/// frame while it animates, and a paint is cheaper than a relayout.
class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    if (value <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * value, size.height),
        radius,
      ),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}

/// A segmented progress bar — the blocky `████████░░` form from the Projects
/// mockup. Reads as a measured quantity rather than a smooth fill.
///
/// Segments light one after another, each easing up to full rather than
/// switching on, so the bar reads as being counted out.
class SegmentedTrack extends StatelessWidget {
  const SegmentedTrack({
    super.key,
    required this.value,
    this.segments = 18,
    this.height = 6,
    this.delay = Duration.zero,
  });

  final double value;
  final int segments;
  final double height;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return EntranceTween<double>(
      begin: 0,
      // Lands on a whole segment: part-lit is for motion, never for rest.
      end: (value.clamp(0.0, 1.0) * segments).round() / segments,
      delay: delay,
      duration: const Duration(milliseconds: 900),
      curve: TraceMotion.emphasizedDecelerate,
      builder: (context, v) {
        // Fractional: the segment at the leading edge is part-lit.
        final lit = segments * v;
        return Row(
          children: List.generate(segments, (i) {
            final t = (lit - i).clamp(0.0, 1.0);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Color.lerp(c.border, c.navy, t),
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
