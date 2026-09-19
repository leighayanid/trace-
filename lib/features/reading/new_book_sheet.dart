import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/form_sheet.dart';
import '../../shared/widgets/trace_sheet.dart';
import 'reading_providers.dart';

/// Adds a book. Title is the only required field.
///
/// NOTE: this shares its container and field styling with NewProjectSheet,
/// OneLineSheet and LogReadingSheet. Four sheets is where the duplication starts
/// to earn extraction into a shared SheetScaffold — see PLAN.md §9.
class NewBookSheet extends ConsumerStatefulWidget {
  const NewBookSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTraceSheet<void>(
      context: context,
      builder: (_) => const NewBookSheet(),
    );
  }

  @override
  ConsumerState<NewBookSheet> createState() => _NewBookSheetState();
}

class _NewBookSheetState extends ConsumerState<NewBookSheet> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _pages = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);

    await ref.read(bookRepositoryProvider).create(
          title: title,
          author: _author.text,
          totalPages: int.tryParse(_pages.text.trim()),
        );

    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      label: 'New book',
      saveLabel: 'Add',
      saving: _saving,
      onSave: _save,
      fields: [
        FieldBox(
          child: BareField(controller: _title, hint: 'Title', autofocus: true),
        ),
        FieldBox(
          child: BareField(controller: _author, hint: 'Author (optional)'),
        ),
        FieldBox(
          child: BareField(
            controller: _pages,
            hint: 'Total pages (optional)',
            number: true,
          ),
        ),
      ],
    );
  }
}
