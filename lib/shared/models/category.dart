import 'package:flutter/material.dart';

/// The four TRACE categories.
///
/// Differentiation is typographic and structural — a label, a glyph, a position.
/// Deliberately *not* four bright colours: CLAUDE.md rules those out, and a navy
/// tint on every tile is what keeps the list quiet.
enum Category {
  build('BUILD', 'Build', Icons.code_rounded),
  read('READ', 'Read', Icons.menu_book_outlined),
  explore('EXPLORE', 'Explore', Icons.public_outlined),
  life('LIFE', 'Life', Icons.spa_outlined);

  const Category(this.label, this.title, this.icon);

  /// Uppercase form used on entry rows: `BUILD`.
  final String label;

  /// Sentence form used in forms and pickers: `Build`.
  final String title;

  final IconData icon;

  static Category? tryParse(String value) {
    final v = value.trim().toLowerCase();
    for (final c in Category.values) {
      if (c.name == v) return c;
    }
    return null;
  }
}
