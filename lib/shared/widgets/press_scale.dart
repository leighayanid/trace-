import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Uniform press feedback: a 0.98 scale on [TraceMotion.fast].
///
/// This replaces Material's ink ripple everywhere — ripples spread colour across
/// a surface, which fights a design built on hairlines and whitespace.
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
    duration: TraceMotion.fast,
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(_) => _controller.forward();
  void _up([_]) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1 - (1 - widget.scale) * _controller.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
