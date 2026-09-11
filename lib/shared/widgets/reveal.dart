import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/theme.dart';

/// Marks the moment a screen's content begins cascading in.
///
/// Every [Reveal] beneath it that is built within
/// [TraceMotion.cascadeWindow] of the scope appearing takes its place in the
/// cascade. Anything built after that — a row scrolled into view, an entry
/// just saved — is not part of the screen arriving, and is handled by
/// [Reveal.late] instead. Without this, scrolling a long list back up would
/// replay the entrance on every row it rebuilt.
class RevealScope extends StatefulWidget {
  const RevealScope({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Holds the whole cascade back — for content arriving under another motion,
  /// such as a page transition, that it should follow rather than race.
  final Duration delay;

  @override
  State<RevealScope> createState() => _RevealScopeState();
}

class _RevealScopeState extends State<RevealScope> {
  final _age = Stopwatch()..start();

  bool get _open => _age.elapsed < widget.delay + TraceMotion.cascadeWindow;

  @override
  Widget build(BuildContext context) =>
      _RevealScopeData(state: this, child: widget.child);
}

class _RevealScopeData extends InheritedWidget {
  const _RevealScopeData({required this.state, required super.child});

  final _RevealScopeState state;

  @override
  bool updateShouldNotify(_RevealScopeData old) => false;
}

/// What a [Reveal] does when it is built after its scope's cascade has ended.
enum RevealLate {
  /// Appear as-is. For content scrolled into view: it was always there.
  none,

  /// Open up from zero height, then fade in. For content that is genuinely new
  /// — the list parts around it rather than jumping.
  expand,
}

/// Content arriving: fades in, rises [TraceMotion.slideY], and optionally comes
/// into focus from a slight blur.
///
/// [order] places it in its screen's cascade. The decision of *how* to arrive
/// is made once, when first built, and never revisited — so a rebuild can
/// neither replay the entrance nor remount the child.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.order = 0,
    this.focus = false,
    this.late = RevealLate.none,
    this.delay = Duration.zero,
  });

  final Widget child;
  final int order;

  /// Resolve out of a blur as well. Reserved for type that should feel like it
  /// is being brought into focus — greetings, titles, the parsed entry.
  final bool focus;

  final RevealLate late;

  /// Extra hold on top of the cascade position.
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

enum _Mode { still, cascade, expand }

class _RevealState extends State<Reveal> {
  _Mode? _mode;
  Duration _start = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mode != null) return;

    if (TraceMotion.reduced(context)) {
      _mode = _Mode.still;
      return;
    }
    final scope =
        context.getInheritedWidgetOfExactType<_RevealScopeData>()?.state;
    if (scope == null || scope._open) {
      _mode = _Mode.cascade;
      // Timed from the scope, not from this widget: rows that arrive a frame
      // late (a database read) still land in their slot rather than restarting
      // the count.
      final elapsed = scope?._age.elapsed ?? Duration.zero;
      final slot = (scope?.widget.delay ?? Duration.zero) +
          TraceMotion.cascade * widget.order +
          widget.delay;
      _start = slot > elapsed ? slot - elapsed : Duration.zero;
    } else {
      _mode = switch (widget.late) {
        RevealLate.none => _Mode.still,
        RevealLate.expand => _Mode.expand,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_mode!) {
      _Mode.still => widget.child,
      _Mode.cascade => _cascade(),
      _Mode.expand => _expand(),
    };
  }

  Widget _cascade() {
    var a = widget.child
        .animate(delay: _start)
        .fadeIn(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
        )
        .moveY(
          begin: TraceMotion.slideY,
          end: 0,
          duration: TraceMotion.slow,
          curve: TraceMotion.emphasizedDecelerate,
        );
    if (widget.focus) {
      a = a.blurXY(
        begin: TraceMotion.focusBlur,
        end: 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
      );
    }
    return a;
  }

  /// Height opens first so the list has made room by the time the content is
  /// visible — nothing is ever drawn on top of a neighbour.
  Widget _expand() {
    return widget.child
        .animate()
        .custom(
          duration: const Duration(milliseconds: 420),
          curve: TraceMotion.emphasized,
          builder: (context, t, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t,
              child: child,
            ),
          ),
        )
        .fadeIn(
          delay: const Duration(milliseconds: 140),
          duration: TraceMotion.base,
          curve: Curves.easeOut,
        )
        .moveY(
          delay: const Duration(milliseconds: 140),
          begin: -6,
          end: 0,
          duration: TraceMotion.slow,
          curve: TraceMotion.emphasizedDecelerate,
        );
  }
}

extension RevealExtension on Widget {
  /// Shorthand for wrapping in a [Reveal].
  Widget reveal(
    int order, {
    bool focus = false,
    RevealLate late = RevealLate.none,
    Duration delay = Duration.zero,
    Key? key,
  }) =>
      Reveal(
        key: key,
        order: order,
        focus: focus,
        late: late,
        delay: delay,
        child: this,
      );
}
