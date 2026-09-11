import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../models/category.dart';

/// The rounded icon tile that opens every entry row.
///
/// Navy-tinted fill, thin glyph. One of the four sanctioned uses of navy.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.category,
    this.size = TraceSize.glyphTile,
    this.heroTag,
  });

  final Category category;
  final double size;

  /// Set to animate the tile across a push to a detail screen.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.navyLight,
        borderRadius: BorderRadius.circular(TraceRadius.glyph),
      ),
      // Changing category turns the glyph over in place: the old one shrinks
      // and fades as the new one grows into the same tile.
      child: AnimatedSwitcher(
        duration: TraceMotion.base,
        switchInCurve: TraceMotion.emphasizedDecelerate,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: Icon(
          category.icon,
          key: ValueKey(category),
          size: size * 0.5,
          color: c.navy,
        ),
      ),
    );

    if (heroTag == null) return tile;
    return Hero(tag: heroTag!, child: tile);
  }
}
