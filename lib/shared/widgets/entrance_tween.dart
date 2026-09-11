import 'package:flutter/widgets.dart';

import '../../app/theme/theme.dart';

/// A [TweenAnimationBuilder] whose *first* run can wait.
///
/// Bars and tickers that fill while their section is still fading in are
/// wasted: by the time the eye arrives the fill is over. [delay] holds the first
/// run back until the content is actually visible. Every later change animates
/// immediately, from the current value to the new one — so logging 27 pages
/// reads as movement along the bar, not a redraw from zero.
class EntranceTween<T extends Object?> extends StatefulWidget {
  const EntranceTween({
    super.key,
    required this.begin,
    required this.end,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = TraceMotion.slow,
    this.curve = TraceMotion.standard,
    this.animate = true,
  });

  final T begin;
  final T end;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final bool animate;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<EntranceTween<T>> createState() => _EntranceTweenState<T>();
}

class _EntranceTweenState<T extends Object?> extends State<EntranceTween<T>> {
  late bool _settled = widget.delay == Duration.zero;

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || TraceMotion.reduced(context)) {
      return widget.builder(context, widget.end);
    }

    // The first run is stretched by the delay, and the curve is pushed into
    // the tail of it, so a single controller covers wait-then-move.
    final total = _settled ? widget.duration : widget.delay + widget.duration;
    final curve = _settled
        ? widget.curve
        : Interval(
            widget.delay.inMicroseconds / total.inMicroseconds,
            1,
            curve: widget.curve,
          );

    return TweenAnimationBuilder<T>(
      tween: Tween<T>(begin: widget.begin, end: widget.end),
      duration: total,
      curve: curve,
      onEnd: () {
        if (!_settled && mounted) setState(() => _settled = true);
      },
      builder: (context, value, _) => widget.builder(context, value),
    );
  }
}
