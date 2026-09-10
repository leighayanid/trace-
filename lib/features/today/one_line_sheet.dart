import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          child: Padding(
            padding: const EdgeInsets.all(TraceSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ONE LINE',
                  style: TraceText.sectionLabel.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: TraceSpace.lg),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: TraceText.body.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'One line about today.',
                    hintStyle:
                        TraceText.body.copyWith(color: c.textSecondary),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: TraceSpace.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _save,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Text(
                        'Save',
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
