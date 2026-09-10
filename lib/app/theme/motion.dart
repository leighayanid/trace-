import 'package:flutter/animation.dart';

/// TRACE motion tokens — the single source for every duration and curve.
///
/// Every animation in this app is a *transition between states*, never idle
/// decoration. Nothing bounces, nothing loops, nothing moves on its own.
abstract final class TraceMotion {
  // ── Durations ─────────────────────────────────────────────────────────────

  /// Taps, toggles, press feedback.
  static const fast = Duration(milliseconds: 180);

  /// Sheets, page transitions, the default.
  static const base = Duration(milliseconds: 280);

  /// Charts drawing, progress tracks filling, value tickers.
  static const slow = Duration(milliseconds: 520);

  /// The splash hold before handing off to Today.
  static const splashHold = Duration(milliseconds: 1200);

  // ── Stagger intervals ─────────────────────────────────────────────────────

  /// Between entry rows revealing on Today.
  static const rowStagger = Duration(milliseconds: 45);

  /// Between suggestion chips in Quick Add.
  static const chipStagger = Duration(milliseconds: 30);

  /// Between arcs of the Insights donut.
  static const arcStagger = Duration(milliseconds: 40);

  /// Between dots in a consistency row.
  static const dotStagger = Duration(milliseconds: 18);

  // ── Curves ────────────────────────────────────────────────────────────────

  /// Things arriving. Decisive, settles without overshoot.
  static const enter = Curves.easeOutExpo;

  /// Things leaving.
  static const exit = Curves.easeInCubic;

  /// Value changes in place — progress fills, tickers.
  static const standard = Curves.easeOutCubic;

  /// Deliberately almost unused. Overshoot reads as playful, and TRACE is not.
  static const spring = Curves.easeOutBack;

  // ── Displacement ──────────────────────────────────────────────────────────

  /// Vertical offset a row travels while fading in.
  static const slideY = 12.0;

  /// Scale applied on press.
  static const pressScale = 0.98;
}
