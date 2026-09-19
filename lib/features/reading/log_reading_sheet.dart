import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/form_sheet.dart';
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
    return FormSheet(
      label: 'Log reading',
      heading: widget.book.title,
      saving: _saving,
      onSave: _save,
      fields: [
        FieldBox(
          label: 'Pages read',
          child: BareField(
            controller: _pages,
            hint: '27',
            autofocus: true,
            number: true,
            style: TraceText.mono.copyWith(fontSize: 17),
            onSubmitted: (_) => _save(),
          ),
        ),
        FieldBox(
          label: 'Current thought (optional)',
          child: BareField(
            controller: _thought,
            hint: 'What stayed with you?',
            minLines: 2,
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
