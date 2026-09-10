import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The tiny letterspaced caps that title every block: `TODAY`, `PRESENCE`.
///
/// Optionally carries a trailing value on the same baseline — `PRESENCE  78%` —
/// which is how the mockup pairs a label with its number.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;

  /// Right-aligned companion, e.g. a mono percentage.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final label = Text(
      text.toUpperCase(),
      style: TraceText.sectionLabel.copyWith(color: c.textSecondary),
    );

    if (trailing == null) return label;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [label, trailing!],
    );
  }
}
