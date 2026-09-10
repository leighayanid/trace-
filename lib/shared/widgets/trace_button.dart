import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

enum TraceButtonVariant {
  /// Navy fill — the primary action. One per screen.
  filled,

  /// Hairline border, no fill.
  outlined,

  /// Bare label, e.g. `View all sessions`.
  text,
}

class TraceButton extends StatelessWidget {
  const TraceButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = TraceButtonVariant.filled,
    this.icon,
    this.fullWidth = true,
  });

  const TraceButton.outlined(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
  }) : variant = TraceButtonVariant.outlined;

  const TraceButton.text(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
  }) : variant = TraceButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final TraceButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final enabled = onPressed != null;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      TraceButtonVariant.filled => (c.navy, c.onNavy, null),
      TraceButtonVariant.outlined => (Colors.transparent, c.textPrimary, c.border),
      TraceButtonVariant.text => (Colors.transparent, c.textSecondary, null),
    };

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: TraceSpace.sm),
        ],
        Text(label, style: TraceText.button.copyWith(color: fg)),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PressScale(
        onTap: onPressed,
        child: Container(
          height: variant == TraceButtonVariant.text
              ? null
              : TraceSize.button,
          padding: variant == TraceButtonVariant.text
              ? const EdgeInsets.symmetric(vertical: TraceSpace.sm)
              : const EdgeInsets.symmetric(horizontal: TraceSpace.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(TraceRadius.button),
            border: border == null ? null : Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}
