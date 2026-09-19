import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/day_picker.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/trace_sheet.dart';
import '../entries/entry_providers.dart';
import '../notes/note_providers.dart';

/// One sentence about the day. Optional, and deliberately tiny.
///
/// A single-line field with no prompts, no templates and no word count — the
/// moment this becomes a journalling workflow it stops being written.
class OneLineSheet extends ConsumerStatefulWidget {
  const OneLineSheet({super.key, this.initial});

  final String? initial;

  static Future<void> show(BuildContext context, {String? initial}) {
    return showTraceSheet<void>(
      context: context,
      builder: (_) => OneLineSheet(initial: initial),
    );
  }

  @override
  ConsumerState<OneLineSheet> createState() => _OneLineSheetState();
}

class _OneLineSheetState extends ConsumerState<OneLineSheet> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final date = ref.read(selectedDateProvider);
    await ref.read(noteRepositoryProvider).setOneLine(date, _controller.text);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.parse(ref.read(selectedDateProvider));
    final today = DateTime.parse(ref.read(currentDayProvider));
    final name = dayLabel(day, today);
    // "about today", "about yesterday", "about Monday" — the sheet names the
    // day it is writing to, since Today can be showing another one.
    final about = name == 'Today' || name == 'Yesterday'
        ? name.toLowerCase()
        : name;
    return FormSheet(
      label: 'One line',
      onSave: _save,
      fields: [
        BareField(
          controller: _controller,
          hint: 'One line about $about.',
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
