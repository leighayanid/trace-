/// TRACE spacing and shape tokens — a 4pt grid.
///
/// Separation comes from hairlines and whitespace, never elevation. There are no
/// shadows anywhere in this app.
abstract final class TraceSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const xxxl = 40.0;

  /// Horizontal screen gutter.
  static const gutter = 20.0;

  /// Vertical gap between labelled sections.
  static const section = 28.0;

  /// Vertical padding inside an entry row.
  static const rowY = 14.0;
}

abstract final class TraceRadius {
  static const card = 12.0;
  static const button = 10.0;
  static const glyph = 8.0;
  static const input = 10.0;
  static const pill = 999.0;
}

abstract final class TraceSize {
  /// The rounded category icon tile on an entry row.
  static const glyphTile = 34.0;

  /// Height of a progress track.
  static const track = 3.0;

  /// The nav bar's centre `+` circle. Prominent, not oversized.
  static const navPlus = 44.0;

  static const navBar = 60.0;

  /// Standard tappable height for full-width buttons.
  static const button = 48.0;
}
