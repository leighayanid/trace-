import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/trace_sheet.dart';
import '../notes/note_providers.dart';

/// Keep a passage from a book, with the page it is on.
///
/// A quote is the author's words; a thought, from Log reading, is yours. They
/// are kept apart so the notes read back as a margin rather than a mix.
class AddQuoteSheet extends ConsumerStatefulWidget {
  const AddQuoteSheet({super.key, required this.book});

  final Book book;

  static Future<void> show(BuildContext context, Book book) {
    return showTraceSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddQuoteSheet(book: book),
    );
  }

  @override
  ConsumerState<AddQuoteSheet> createState() => _AddQuoteSheetState();
}

class _AddQuoteSheetState extends ConsumerState<AddQuoteSheet> {
  final _quote = TextEditingController();
  final _page = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _quote.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_quote.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);

    final page = int.tryParse(_page.text.trim());
    await ref.read(noteRepositoryProvider).addBookNote(
          widget.book.id,
          _quote.text,
          kind: 'quote',
          page: page != null && page > 0 ? page : null,
        );

    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return FormSheet(
      label: 'Add quote',
      heading: widget.book.title,
      saving: _saving,
      onSave: _save,
      fields: [
        FieldBox(
          label: 'Quote',
          child: TextField(
            controller: _quote,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: TraceText.quote.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'The words, as they are on the page.',
              hintStyle: TraceText.body.copyWith(color: c.textSecondary),
            ),
          ),
        ),
        FieldBox(
          label: 'Page (optional)',
          child: TextField(
            controller: _page,
            keyboardType: TextInputType.number,
            style: TraceText.mono.copyWith(color: c.textPrimary, fontSize: 17),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '42',
              hintStyle: TraceText.mono.copyWith(color: c.textSecondary),
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
      ],
    );
  }
}
