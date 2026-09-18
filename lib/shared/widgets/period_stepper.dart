import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// `‹ September 2026 ›` — steps a view back and forth through time.
///
/// Shared by Timeline (months) and Insights (months or years), so moving
/// through the past looks and moves the same way everywhere.
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    super.key,
    required this.label,
    required this.direction,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;

  /// Which way the last step went: -1 back, +1 forward. The label rolls in
  /// from that side.
  final int direction;

  final VoidCallback onPrevious;

  /// Null at the present, since stepping into the future would only ever show
  /// emptiness.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Row(
      children: [
        PressScale(
          onTap: onPrevious,
          child: Padding(
            padding: const EdgeInsets.all(TraceSpace.xs),
            child: Icon(Icons.chevron_left_rounded,
                size: 20, color: c.textSecondary),
          ),
        ),
        const SizedBox(width: TraceSpace.sm),
        // The label rolls in from the side the period came from, and the right
        // chevron glides to the new label's width rather than jumping.
        AnimatedSize(
          duration: TraceMotion.page,
          curve: TraceMotion.emphasized,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: TraceMotion.page,
            switchInCurve: TraceMotion.emphasizedDecelerate,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(label);
              // Arrivals come from the side stepped towards; departures leave
              // towards the other.
              final side = (incoming ? direction : -direction).toDouble();
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(0.35 * side, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              label,
              key: ValueKey(label),
              style: TraceText.categoryLabel.copyWith(color: c.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: TraceSpace.sm),
        PressScale(
          onTap: onNext,
          child: Padding(
            padding: const EdgeInsets.all(TraceSpace.xs),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: onNext != null ? c.textSecondary : c.border,
              ),
              duration: TraceMotion.base,
              builder: (context, color, _) =>
                  Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ),
          ),
        ),
      ],
    );
  }
}
