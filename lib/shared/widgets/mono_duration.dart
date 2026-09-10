import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// How a duration renders.
enum DurationFormat {
  /// `02:34` — the entry-row and timeline form.
  clock,

  /// `2h 34m` — the form-field and session-list form.
  human,
}

String formatDuration(Duration d, DurationFormat format) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  switch (format) {
    case DurationFormat.clock:
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    case DurationFormat.human:
      if (h == 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
  }
}

/// A duration in mono, which *counts* to its value rather than popping into it.
///
/// Tabular figures come from [TraceText.mono], so the glyph box never reflows
/// mid-animation.
class MonoDuration extends StatelessWidget {
  const MonoDuration(
    this.duration, {
    super.key,
    this.format = DurationFormat.clock,
    this.style,
    this.color,
    this.animate = true,
  });

  final Duration duration;
  final DurationFormat format;
  final TextStyle? style;
  final Color? color;

  /// Off for static contexts such as a long scrolling list, where dozens of
  /// simultaneous tickers would be noise rather than texture.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final resolved =
        (style ?? TraceText.mono).copyWith(color: color ?? c.textPrimary);

    if (!animate) {
      return Text(formatDuration(duration, format), style: resolved);
    }

    return TweenAnimationBuilder<Duration>(
      tween: Tween(begin: Duration.zero, end: duration),
      duration: TraceMotion.slow,
      curve: TraceMotion.standard,
      builder: (context, value, _) =>
          Text(formatDuration(value, format), style: resolved),
    );
  }
}

/// An integer in mono that counts to its value — percentages, pages, day counts.
class MonoValue extends StatelessWidget {
  const MonoValue(
    this.value, {
    super.key,
    this.suffix = '',
    this.style,
    this.color,
    this.animate = true,
  });

  final int value;
  final String suffix;
  final TextStyle? style;
  final Color? color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final resolved =
        (style ?? TraceText.mono).copyWith(color: color ?? c.textPrimary);

    if (!animate) return Text('$value$suffix', style: resolved);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: TraceMotion.slow,
      curve: TraceMotion.standard,
      builder: (context, v, _) =>
          Text('${v.round()}$suffix', style: resolved),
    );
  }
}
