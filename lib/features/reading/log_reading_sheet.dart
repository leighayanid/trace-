import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/trace_sheet.dart';
import '../../core/database/database.dart';
import '../notes/note_providers.dart';
import 'reading_providers.dart';

/// Log a reading session: pages read, and optionally the thought it left.
///
/// Two fields, one save. This writes the READ entry, advances the book, and
/// stores the thought — the user should never have to record the same session in
/// three places.
class LogReadingSheet extends ConsumerStatefulWidget {
  const LogReadingSheet({super.key, required this.book});

  final Book book;

  static Future<void> show(BuildContext context, Book book) {
    return showTraceSheet<void>(
      context: context,
      builder: (_) => LogReadingSheet(book: book),
    );
  }

  @override
  ConsumerState<LogReadingSheet> createState() => _LogReadingSheetState();
}

class _LogReadingSheetState extends ConsumerState<LogReadingSheet> {
  final _pages = TextEditingController();
  final _thought = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    _thought.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pages = int.tryParse(_pages.text.trim());
    if (pages == null || pages <= 0 || _saving) return;
    setState(() => _saving = true);

    await ref.read(bookRepositoryProvider).logSession(
          book: widget.book,
          pagesRead: pages,
          thought: _thought.text,
        );

    final thought = _thought.text.trim();
    if (thought.isNotEmpty) {
      await ref
          .read(noteRepositoryProvider)
          .addBookNote(widget.book.id, thought);
    }

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TraceSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOG READING',
                    style: TraceText.sectionLabel
                        .copyWith(color: c.textSecondary)),
                const SizedBox(height: TraceSpace.lg),
                Text(widget.book.title,
                    style: TraceText.bookTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: TraceSpace.xl),
                Text('Pages read',
                    style:
                        TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
                const SizedBox(height: TraceSpace.sm),
                _box(
                  context,
                  TextField(
                    controller: _pages,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TraceText.mono.copyWith(
                      color: c.textPrimary,
                      fontSize: 17,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '27',
                      hintStyle:
                          TraceText.mono.copyWith(color: c.textSecondary),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(height: TraceSpace.lg),
                Text('Current thought (optional)',
                    style:
                        TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
                const SizedBox(height: TraceSpace.sm),
                _box(
                  context,
                  TextField(
                    controller: _thought,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: TraceText.body.copyWith(color: c.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What stayed with you?',
                      hintStyle:
                          TraceText.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: TraceSpace.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: PressScale(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Text(
                        _saving ? 'Saving…' : 'Save',
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

  Widget _box(BuildContext context, Widget child) {
    final c = context.traceColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TraceSpace.md,
        vertical: TraceSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(TraceRadius.card),
      ),
      child: child,
    );
  }
}
