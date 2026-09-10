import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import 'reading_providers.dart';

/// Adds a book. Title is the only required field.
///
/// NOTE: this shares its container and field styling with NewProjectSheet,
/// OneLineSheet and LogReadingSheet. Four sheets is where the duplication starts
/// to earn extraction into a shared SheetScaffold — see PLAN.md §9.
class NewBookSheet extends ConsumerStatefulWidget {
  const NewBookSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                Text('NEW BOOK',
                    style: TraceText.sectionLabel
                        .copyWith(color: c.textSecondary)),
                const SizedBox(height: TraceSpace.xl),
                _field(context, _title, 'Title', autofocus: true),
                const SizedBox(height: TraceSpace.lg),
                _field(context, _author, 'Author (optional)'),
                const SizedBox(height: TraceSpace.lg),
                _field(context, _pages, 'Total pages (optional)',
                    number: true),
                const SizedBox(height: TraceSpace.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _save,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Text(
                        _saving ? 'Saving…' : 'Add',
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

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    bool autofocus = false,
    bool number = false,
  }) {
    final c = context.traceColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TraceSpace.md,
        vertical: TraceSpace.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(TraceRadius.card),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: number ? TextInputType.number : null,
        style: (number ? TraceText.mono : TraceText.body)
            .copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }
}
