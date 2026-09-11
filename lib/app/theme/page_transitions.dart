import 'package:flutter/material.dart';

import 'motion.dart';

/// The page transition: depth, not direction.
///
/// Sliding sideways implies the screens sit next to each other on a strip; they
/// don't. A detail screen sits *on top of* the list it came from, so the new
/// page rises into place and comes into view while the page underneath recedes
/// a few percent and dims out — the way a sheet of paper is laid on a desk.
///
/// The two halves are deliberately offset. The outgoing page is mostly gone
/// before the incoming one is mostly there, so the two never read as a muddy
/// double exposure.
///
/// Under reduced motion both halves keep their fades and drop all movement —
/// by zeroing the distances rather than swapping in a different transition,
/// so the page is never remounted when the setting changes.
class TracePageTransitionsBuilder extends PageTransitionsBuilder {
  const TracePageTransitionsBuilder();

  @override
  Duration get transitionDuration => TraceMotion.page;

  @override
  Duration get reverseTransitionDuration => TraceMotion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return recede(
      secondaryAnimation,
      child: _Arrive(animation: animation, child: child),
    );
  }

  /// The outgoing half, on its own: the page underneath recedes and dims as
  /// another page is laid over it, then comes forward again as that page
  /// leaves. Public so a custom route can recede like every other page.
  static Widget recede(Animation<double> secondary, {required Widget child}) =>
      _Recede(animation: secondary, child: child);
}

/// The incoming half: rise, scale up the last few percent, and fade in. On pop
/// the same page sinks back and is gone within the first half.
class _Arrive extends StatefulWidget {
  const _Arrive({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> {
  late CurvedAnimation _move;
  late CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(_Arrive old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _dispose();
      _bind();
    }
  }

  // Owned here rather than built per call: a CurvedAnimation registers a
  // listener on its parent the moment it exists, and transitions rebuild.
  void _bind() {
    _move = CurvedAnimation(
      parent: widget.animation,
      curve: TraceMotion.emphasizedDecelerate,
      reverseCurve: TraceMotion.emphasizedAccelerate.flipped,
    );
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.12, 0.62, curve: Curves.easeOut),
      reverseCurve: const Interval(0.45, 1.0, curve: Curves.easeIn),
    );
  }

  void _dispose() {
    _move.dispose();
    _fade.dispose();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = TraceMotion.reduced(context);
    final rise = reduced ? 0.0 : TraceMotion.pageRise;
    final grow = reduced ? 0.0 : 0.015;

    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final t = _move.value;
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * rise),
            child: Transform.scale(
              scale: 1 - grow * (1 - t),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _Recede extends StatefulWidget {
  const _Recede({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_Recede> createState() => _RecedeState();
}

class _RecedeState extends State<_Recede> {
  late CurvedAnimation _depth;
  late CurvedAnimation _fade;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(_Recede old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _dispose();
      _bind();
    }
  }

  void _bind() {
    _depth = CurvedAnimation(
      parent: widget.animation,
      curve: TraceMotion.emphasizedDecelerate,
      // Coming forward again decelerates too: quick off the mark, soft landing.
      reverseCurve: TraceMotion.emphasizedDecelerate.flipped,
    );
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      reverseCurve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );
  }

  void _dispose() {
    _depth.dispose();
    _fade.dispose();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shrink =
        TraceMotion.reduced(context) ? 0.0 : 1 - TraceMotion.pageRecede;

    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      // The wrapper stays in the tree even at rest — swapping it in and out
      // would remount the page and drop its state. At rest it costs nothing:
      // full opacity and an identity transform both paint straight through.
      builder: (context, child) => Opacity(
        opacity: 1 - _fade.value,
        child: Transform.scale(scale: 1 - shrink * _depth.value, child: child),
      ),
    );
  }
}
