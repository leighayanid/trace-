import 'package:flutter/material.dart';

/// TRACE type scale.
///
/// The whole visual identity is one rule: **every number is mono, every word is
/// sans.** Mono styles carry tabular figures so animated values do not jitter as
/// digits change width.
abstract final class TraceText {
  static const _sans = 'Inter';
  static const _mono = 'IBMPlexMono';

  /// Digits that never change width. Required on anything that animates.
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  // ── Display ───────────────────────────────────────────────────────────────

  /// Splash wordmark: `T R A C E`. Tracking is animated 18 → 12 on entry.
  static const wordmark = TextStyle(
    fontFamily: _sans,
    fontSize: 28,
    fontWeight: FontWeight.w300,
    letterSpacing: 12,
    height: 1.2,
  );

  /// Small tracked wordmark in the Today header.
  static const wordmarkSmall = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    height: 1.2,
  );

  /// Screen titles: `Add Entry`, `Timeline`, `Insights`.
  static const screenTitle = TextStyle(
    fontFamily: _sans,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// The greeting name: `Leigh.`
  static const greetingName = TextStyle(
    fontFamily: _sans,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.15,
  );

  /// `Good evening,`
  static const greetingLine = TextStyle(
    fontFamily: _sans,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // ── Structure ─────────────────────────────────────────────────────────────

  /// Tiny letterspaced caps: `TODAY`, `PRESENCE`, `ONE LINE`.
  static const sectionLabel = TextStyle(
    fontFamily: _sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    height: 1.2,
  );

  /// Category caps on an entry row: `BUILD`.
  static const categoryLabel = TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// Bottom navigation destinations: `Today`, `Timeline`.
  static const navLabel = TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// The grey line beneath a category label.
  static const rowSubtitle = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // ── Content ───────────────────────────────────────────────────────────────

  static const bookTitle = TextStyle(
    fontFamily: _sans,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const quote = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.5,
  );

  static const body = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const button = TextStyle(
    fontFamily: _sans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // ── Mono — every number in the app ────────────────────────────────────────

  /// Durations and stats on rows: `02:34`.
  static const mono = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
  );

  /// Small mono, e.g. percentage beside a progress track.
  static const monoSmall = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    fontFeatures: _tabular,
  );

  /// The day number in the Timeline gutter.
  static const monoLarge = TextStyle(
    fontFamily: _mono,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.1,
    fontFeatures: _tabular,
  );

  /// Donut centre total: `78h`.
  static const monoStat = TextStyle(
    fontFamily: _mono,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.1,
    fontFeatures: _tabular,
  );
}
