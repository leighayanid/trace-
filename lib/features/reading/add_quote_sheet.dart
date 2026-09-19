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
    return FormSheet(
      label: 'Add quote',
      heading: widget.book.title,
      saving: _saving,
      onSave: _save,
      fields: [
        FieldBox(
          label: 'Quote',
          child: BareField(
            controller: _quote,
            hint: 'The words, as they are on the page.',
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            style: TraceText.quote,
          ),
        ),
        FieldBox(
          label: 'Page (optional)',
          child: BareField(
            controller: _page,
            hint: '42',
            number: true,
            style: TraceText.mono.copyWith(fontSize: 17),
            onSubmitted: (_) => _save(),
          ),
        ),
      ],
    );
  }
}
