import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Uniform press feedback: a 0.98 scale.
///
/// This replaces Material's ink ripple everywhere — ripples spread colour across
/// a surface, which fights a design built on hairlines and whitespace.
///
/// The press goes in quickly and comes out slowly, like a key returning. A tap
/// too quick to register a press on its own (common inside a scroll view, where
/// tap-down waits for the gesture to resolve) still plays the full press, so
/// every tap is acknowledged.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = TraceMotion.pressScale,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _press = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    // Decelerates on the way out too: quick to lift, slow to settle.
    reverseCurve: Curves.easeOutCubic.flipped,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(_) => _controller.forward();

  void _up([_]) {
    if (_controller.value >= 0.6) {
      _controller.reverse();
      return;
    }
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted) _controller.reverse();
    });
  }

  void _cancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    // The same tree whether enabled or not, so a button becoming enabled
    // doesn't remount its contents and cut short whatever they were animating.
    final enabled = widget.onTap != null;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? _down : null,
      onTapUp: enabled ? _up : null,
      onTapCancel: enabled ? _cancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) => Transform.scale(
          scale: 1 - (1 - widget.scale) * _press.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
