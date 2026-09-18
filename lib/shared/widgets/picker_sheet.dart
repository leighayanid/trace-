import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// A titled list of choices, shown in a trace sheet. Used wherever one
/// thing is picked from a few — category, project, book, day.
class PickerSheet extends StatelessWidget {
  const PickerSheet({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TraceSpace.gutter,
                TraceSpace.xl,
                TraceSpace.gutter,
                TraceSpace.md,
              ),
              child: Text(
                title.toUpperCase(),
                style: TraceText.sectionLabel.copyWith(color: c.textSecondary),
              ),
            ),
            ...children,
            const SizedBox(height: TraceSpace.md),
          ],
        ),
      ),
    );
  }
}

class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.gutter,
          vertical: TraceSpace.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: TraceSpace.md),
            ],
            Expanded(
              child: Text(
                label,
                style: TraceText.body.copyWith(color: c.textPrimary),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: c.navy),
          ],
        ),
      ),
    );
  }
}
