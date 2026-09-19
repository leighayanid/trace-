import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// A small form in a bottom sheet: a caps label, an optional heading, the
/// fields, and Save.
///
/// Lifts above the keyboard and scrolls if it has to, so a sheet never needs to
/// think about either.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.label,
    this.heading,
    required this.fields,
    required this.onSave,
    this.saving = false,
  });

  /// `LOG READING` — what the sheet does.
  final String label;

  /// What it is about, in the book face — usually the book's title.
  final String? heading;

  final List<Widget> fields;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TraceSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TraceText.sectionLabel
                        .copyWith(color: c.textSecondary)),
                if (heading != null) ...[
                  const SizedBox(height: TraceSpace.lg),
                  Text(heading!,
                      style:
                          TraceText.bookTitle.copyWith(color: c.textPrimary)),
                ],
                const SizedBox(height: TraceSpace.xl),
                for (final (i, f) in fields.indexed) ...[
                  if (i > 0) const SizedBox(height: TraceSpace.lg),
                  f,
                ],
                const SizedBox(height: TraceSpace.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: PressScale(
                    onTap: onSave,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Text(
                        saving ? 'Saving…' : 'Save',
                        style: TraceText.button.copyWith(color: c.navy),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled, bordered box around one input.
class FieldBox extends StatelessWidget {
  const FieldBox({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
        const SizedBox(height: TraceSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TraceSpace.md,
            vertical: TraceSpace.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(TraceRadius.card),
          ),
          child: child,
        ),
      ],
    );
  }
}
