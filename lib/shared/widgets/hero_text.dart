import 'package:flutter/material.dart';

/// Text that carries itself from one screen to the next.
///
/// A project's name is 17pt in the list and 26pt as the detail screen's title.
/// A plain [Hero] would fly the destination text and stretch it to fit — the
/// glyphs visibly scale. This interpolates the *style* instead, so the name
/// re-sets itself at each size along the way, the way type does in print.
///
/// Both ends must use the same [tag], and the tag must be unique on screen.
class HeroText extends StatelessWidget {
  const HeroText(
    this.text, {
    super.key,
    required this.tag,
    required this.style,
    this.maxLines,
  });

  final String text;
  final Object tag;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      // Straight line, not Material's arc: type moving on a curve reads as
      // thrown, and this should read as re-set.
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: _shuttle,
      child: _HeroTextBody(text: text, style: style, maxLines: maxLines),
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final from = (fromContext.widget as Hero).child as _HeroTextBody;
    final to = (toContext.widget as Hero).child as _HeroTextBody;

    // The route animation always runs 0 → 1 as the detail screen arrives, in
    // both directions — so on a pop, `from` is the detail end.
    final (list, detail) =
        direction == HeroFlightDirection.push ? (from, to) : (to, from);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => _HeroTextBody(
        text: detail.text,
        style: TextStyle.lerp(list.style, detail.style, animation.value)!,
        maxLines: detail.maxLines,
        // Mid-flight the box is sized for neither end; letting a long title
        // rewrap between the two would make it jump.
        inFlight: true,
      ),
    );
  }
}

class _HeroTextBody extends StatelessWidget {
  const _HeroTextBody({
    required this.text,
    required this.style,
    this.maxLines,
    this.inFlight = false,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final bool inFlight;

  @override
  Widget build(BuildContext context) {
    // The flight is drawn in the overlay, outside any Material — without this
    // the text picks up the debug fallback style.
    return Material(
      type: MaterialType.transparency,
      child: Text(
        text,
        style: style,
        maxLines: inFlight ? 1 : maxLines,
        softWrap: !inFlight,
        overflow: inFlight ? TextOverflow.visible : null,
      ),
    );
  }
}
