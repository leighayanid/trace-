import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// A small form in a bottom sheet: a caps label, an optional heading, the
/// fields, and Save.
///
/// Every sheet that creates or logs something is one of these, so they share a
/// shape: lift above the keyboard, scroll if they have to, and end in the same
/// quiet navy action. A field is any widget — usually a [FieldBox], but the one
/// line on Today is deliberately bare.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.label,
    this.heading,
    required this.fields,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Save',
  });

  /// `LOG READING` — what the sheet does.
  final String label;

  /// What it is about, in the book face — usually the book's title.
  final String? heading;

  final List<Widget> fields;
  final VoidCallback onSave;
  final bool saving;

  /// What the action says — Save, Create, Add.
  final String saveLabel;

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
                        saving ? 'Saving…' : saveLabel,
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

/// A bordered box around one input, with an optional label above it and an
/// optional note below.
class FieldBox extends StatelessWidget {
  const FieldBox({super.key, this.label, this.note, required this.child});

  final String? label;

  /// A line of explanation under the box.
  final String? note;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
          const SizedBox(height: TraceSpace.sm),
        ],
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
        if (note != null) ...[
          const SizedBox(height: TraceSpace.sm),
          Text(
            note!,
            style: TraceText.rowSubtitle
                .copyWith(color: c.textSecondary, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// A text input with no chrome of its own — the [FieldBox] or the sheet around
/// it supplies the frame. Numbers set in mono, like every number in TRACE.
class BareField extends StatelessWidget {
  const BareField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.number = false,
    this.minLines,
    this.maxLines = 1,
    this.style,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final bool number;
  final int? minLines;
  final int maxLines;

  /// Overrides the text style: body, or mono for numbers.
  final TextStyle? style;

  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final base = style ?? (number ? TraceText.mono : TraceText.body);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      // Text keyboards keep their Done key even when the field wraps, so
      // Enter saves rather than starting a second line.
      keyboardType: number ? TextInputType.number : null,
      textCapitalization:
          number ? TextCapitalization.none : TextCapitalization.sentences,
      minLines: minLines,
      maxLines: maxLines,
      style: base.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: (number ? TraceText.mono : TraceText.body)
            .copyWith(color: c.textSecondary),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
