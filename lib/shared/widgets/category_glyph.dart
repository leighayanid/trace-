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
      child: Icon(
        category.icon,
        size: size * 0.5,
        color: c.navy,
      ),
    );

    if (heroTag == null) return tile;
    return Hero(tag: heroTag!, child: tile);
  }
}
