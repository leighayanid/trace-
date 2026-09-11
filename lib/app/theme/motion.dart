import 'package:flutter/widgets.dart';

/// TRACE motion tokens — the single source for every duration and curve.
///
/// Every animation in this app is a *transition between states*, never idle
/// decoration. Nothing bounces, nothing loops, nothing moves on its own.
///
/// What makes motion read as considered rather than default is mostly two
/// things: emphasized curves (a decisive start, then a long soft landing) and
/// choreography (things arriving in a deliberate order, not all at once).
abstract final class TraceMotion {
  // ── Durations ─────────────────────────────────────────────────────────────

  /// Taps, toggles, press feedback.
  static const fast = Duration(milliseconds: 180);

  /// Small state changes and cross-fades.
  static const base = Duration(milliseconds: 280);

  /// Tab changes: long enough to register as movement, short enough that a
  /// fast thumb never waits on it.
  static const tab = Duration(milliseconds: 340);

  /// Charts drawing, progress tracks filling, value tickers.
  static const slow = Duration(milliseconds: 520);

  /// A page pushing. Depth needs a little more time than a fade to be felt.
  static const page = Duration(milliseconds: 460);

  /// A page popping. Leaving is always quicker than arriving.
  static const pageReverse = Duration(milliseconds: 360);

  /// A sheet rising.
  static const sheet = Duration(milliseconds: 440);

  /// A sheet dismissing.
  static const sheetReverse = Duration(milliseconds: 280);

  /// Splash → app. Slower than a page: the app settling into view.
  static const settle = Duration(milliseconds: 720);

  /// The splash hold before its exit begins.
  static const splashHold = Duration(milliseconds: 800);

  /// The splash's own exit, before handing off to Today.
  static const splashExit = Duration(milliseconds: 480);

  // ── Choreography ──────────────────────────────────────────────────────────

  /// Between blocks of content cascading into a screen.
  static const cascade = Duration(milliseconds: 55);

  /// How long after a screen first builds its content still cascades in.
  /// Anything built later — scrolled into view, inserted — arrives on its own.
  static const cascadeWindow = Duration(milliseconds: 900);

  /// Between suggestion chips in Quick Add.
  static const chipStagger = Duration(milliseconds: 30);

  /// Between dots in a consistency row.
  static const dotStagger = Duration(milliseconds: 18);

  // ── Curves ────────────────────────────────────────────────────────────────

  /// Things arriving. Decisive, settles without overshoot.
  static const enter = Curves.easeOutExpo;

  /// Value changes in place — progress fills, tickers.
  static const standard = Curves.easeOutCubic;

  /// Material 3's emphasized easing: for movement that spans a distance and
  /// should feel intentional — indicators gliding, thumbs sliding.
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Emphasized, arriving: most of the distance covered almost at once, then a
  /// long, soft landing. The signature curve of this app.
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized, leaving: a gentle start that gathers pace as it goes.
  ///
  /// When a leaving motion runs as a *reversed* animation — a sheet closing, a
  /// page popping — pass `emphasizedAccelerate.flipped` as the reverse curve,
  /// so it still accelerates away rather than decelerating.
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Deliberately almost unused. Overshoot reads as playful, and TRACE is not.
  static const spring = Curves.easeOutBack;

  // ── Displacement ──────────────────────────────────────────────────────────

  /// Vertical offset a row travels while fading in.
  static const slideY = 12.0;

  /// Blur content comes into focus from, in logical pixels of sigma.
  static const focusBlur = 6.0;

  /// Distance an incoming page rises.
  static const pageRise = 28.0;

  /// Scale the page underneath recedes to as another pushes over it.
  static const pageRecede = 0.94;

  /// Scale applied on press.
  static const pressScale = 0.98;

  // ── Accessibility ─────────────────────────────────────────────────────────

  /// Whether the user has asked the system for less motion.
  ///
  /// Every choreographed effect checks this and collapses to its end state —
  /// or, for navigation, to a plain cross-fade, so there is still a cue that
  /// something changed.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
