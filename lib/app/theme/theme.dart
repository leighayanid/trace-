import 'package:flutter/material.dart';

import 'colors.dart';
import 'page_transitions.dart';
import 'spacing.dart';
import 'typography.dart';

export 'colors.dart';
export 'motion.dart';
export 'page_transitions.dart';
export 'spacing.dart';
export 'typography.dart';

/// Assembles [ThemeData] from the TRACE tokens.
///
/// Material defaults are stripped back hard: no elevation, no splash ripples, no
/// tinted surfaces. The mockup has none of those, and a single stray default
/// reads as a different app.
abstract final class TraceTheme {
  static ThemeData light() => _build(TraceColors.light, Brightness.light);

  static ThemeData dark() => _build(TraceColors.dark, Brightness.dark);

  static ThemeData _build(TraceColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.navy,
        brightness: brightness,
      ).copyWith(
        surface: c.bg,
        primary: c.navy,
        onPrimary: c.onNavy,
        outline: c.border,
      ),

      // Flat by decree. Separation is hairlines and whitespace.
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary, size: 20),
        titleTextStyle: TraceText.screenTitle.copyWith(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TraceRadius.card),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),

      // No ripples. Press feedback is a 0.98 scale, applied by TraceButton.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      textTheme: _textTheme(c),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.navy,
        selectionColor: c.navy.withValues(alpha: 0.20),
        selectionHandleColor: c.navy,
      ),

      // Every platform, so desktop builds don't fall back to Material's zoom.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const TracePageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TraceColors c) {
    final primary = c.textPrimary;
    final secondary = c.textSecondary;
    return TextTheme(
      displayLarge: TraceText.greetingName.copyWith(color: primary),
      headlineMedium: TraceText.screenTitle.copyWith(color: primary),
      titleMedium: TraceText.bookTitle.copyWith(color: primary),
      bodyLarge: TraceText.body.copyWith(color: primary),
      bodyMedium: TraceText.rowSubtitle.copyWith(color: secondary),
      labelSmall: TraceText.sectionLabel.copyWith(color: secondary),
      labelMedium: TraceText.categoryLabel.copyWith(color: primary),
    );
  }
}
