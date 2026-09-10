import 'package:flutter/material.dart';

/// TRACE colour tokens.
///
/// Navy is an accent, not a surface. It is load-bearing in exactly four places:
/// the primary button fill, the nav bar's centre `+`, progress-track fills, and
/// the category glyph tiles. Everywhere else is monochrome.
@immutable
class TraceColors extends ThemeExtension<TraceColors> {
  const TraceColors({
    required this.bg,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.navy,
    required this.navyLight,
    required this.onNavy,
  });

  final Color bg;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color navy;
  final Color navyLight;

  /// Text/icon colour when sitting on a navy fill.
  final Color onNavy;

  static const light = TraceColors(
    bg: Color(0xFFF8F8F6),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF6B6B6B),
    border: Color(0xFFE4E4E1),
    navy: Color(0xFF0B1F3A),
    navyLight: Color(0xFFE8EDF3),
    onNavy: Color(0xFFFFFFFF),
  );

  static const dark = TraceColors(
    bg: Color(0xFF0B0D10),
    surface: Color(0xFF14171C),
    textPrimary: Color(0xFFF5F5F2),
    textSecondary: Color(0xFF858991),
    border: Color(0xFF242830),
    navy: Color(0xFF18365A),
    navyLight: Color(0xFF16233A),
    onNavy: Color(0xFFF5F5F2),
  );

  @override
  TraceColors copyWith({
    Color? bg,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? navy,
    Color? navyLight,
    Color? onNavy,
  }) {
    return TraceColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      navy: navy ?? this.navy,
      navyLight: navyLight ?? this.navyLight,
      onNavy: onNavy ?? this.onNavy,
    );
  }

  @override
  TraceColors lerp(ThemeExtension<TraceColors>? other, double t) {
    if (other is! TraceColors) return this;
    return TraceColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      navyLight: Color.lerp(navyLight, other.navyLight, t)!,
      onNavy: Color.lerp(onNavy, other.onNavy, t)!,
    );
  }
}

/// `context.traceColors` — the way every widget reads colour.
extension TraceColorsX on BuildContext {
  TraceColors get traceColors => Theme.of(this).extension<TraceColors>()!;
}
