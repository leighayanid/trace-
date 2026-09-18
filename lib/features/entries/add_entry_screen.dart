import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/parser/duration_grammar.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/category_glyph.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/save_sweep.dart';
import '../../shared/widgets/trace_button.dart';
import '../../shared/widgets/trace_sheet.dart';
import 'entry_draft.dart';
import 'entry_providers.dart';

/// The confirmation form. Every field the parser proposed is editable here —
/// the parser suggests, the user decides.
class AddEntryScreen extends ConsumerStatefulWidget {
  const AddEntryScreen({super.key, required this.draft, this.entryId});

  /// What the form opens with: the parser's proposal, or the stored entry.
  final EntryDraft draft;

  /// Set when editing an existing entry rather than creating one.
  final String? entryId;

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  late Category _category = widget.draft.category;
  late String _title = widget.draft.title;
  late Duration? _duration = widget.draft.duration;
  late double? _quantity = widget.draft.quantity;
  late String? _quantityUnit = widget.draft.quantityUnit;
  late String? _projectId = widget.draft.projectId;
  late String? _bookId = widget.draft.bookId;
  // Opens with the entry's note when editing — an empty box would read as a
  // note that was never written, and saving it would erase the real one.
  late final _noteController =
      TextEditingController(text: widget.draft.description);
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final repo = ref.read(entryRepositoryProvider);
    final draft = EntryDraft(
      category: _category,
      title: _title.trim(),
      description: _noteController.text,
      duration: _duration,
      quantity: _quantity,
      quantityUnit: _quantityUnit,
      projectId: _projectId,
      bookId: _bookId,
    );

    if (widget.entryId != null) {
      await repo.save(widget.entryId!, draft);
    } else {
      await repo.create(draft);
    }

    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final projects = ref.watch(projectsProvider).value ?? const [];
    final projectName = _projectId == null
        ? null
        : projects.where((p) => p.id == _projectId).firstOrNull?.name;
    final books = ref.watch(booksProvider).value ?? const [];
    final bookTitle = _bookId == null
        ? null
        : books.where((b) => b.id == _bookId).firstOrNull?.title;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(context),
            // Sweeps left to right beneath the Save row, then the screen pops.
            SaveSweep(active: _saving),
            Expanded(
              // The form follows the page in, field by field, top to bottom —
              // the order it is filled in.
              child: RevealScope(
                delay: const Duration(milliseconds: 120),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    context.gutter,
                    0,
                    context.gutter,
                    TraceSpace.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.entryId == null ? 'Add Entry' : 'Edit Entry',
                        style: TraceText.screenTitle
                            .copyWith(color: c.textPrimary),
                      ).reveal(0, focus: true),
                      const SizedBox(height: TraceSpace.xl),
                      _categoryRow(context).reveal(1),
                      const SizedBox(height: TraceSpace.xl),
                      _labelled(
                        context,
                        'Title',
                        _TextRow(
                          value: _title,
                          hint: 'What was it?',
                          onChanged: (v) => setState(() => _title = v),
                        ),
                      ).reveal(2),
                      // Project belongs to BUILD and Book to READ. Switching
                      // category folds the field open or shut, so the form
                      // below moves rather than jumps.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: TraceMotion.emphasized,
                        switchOutCurve: TraceMotion.emphasized,
                        transitionBuilder: (child, animation) => SizeTransition(
                          sizeFactor: animation,
                          alignment: AlignmentDirectional.topStart,
                          child:
                              FadeTransition(opacity: animation, child: child),
                        ),
                        child: switch (_category) {
                          Category.build => Padding(
                              key: const ValueKey('project'),
                              padding:
                                  const EdgeInsets.only(top: TraceSpace.xl),
                              child: _labelled(
                                context,
                                'Project',
                                _tappableRow(
                                  context,
                                  projectName ?? 'None',
                                  muted: projectName == null,
                                  onTap: () => _pickProject(context),
                                ),
                              ),
                            ),
                          Category.read => Padding(
                              key: const ValueKey('book'),
                              padding:
                                  const EdgeInsets.only(top: TraceSpace.xl),
                              child: _labelled(
                                context,
                                'Book',
                                _tappableRow(
                                  context,
                                  bookTitle ?? 'None',
                                  muted: bookTitle == null,
                                  onTap: () => _pickBook(context),
                                ),
                              ),
                            ),
                          _ => const SizedBox(key: ValueKey('no-link')),
                        },
                      ).reveal(3),
                      const SizedBox(height: TraceSpace.xl),
                      _labelled(
                        context,
                        'Duration',
                        _tappableRow(
                          context,
                          _duration == null
                              ? 'None'
                              : formatDuration(
                                  _duration!, DurationFormat.human),
                          muted: _duration == null,
                          mono: _duration != null,
                          onTap: _pickDuration,
                        ),
                      ).reveal(4),
                      const SizedBox(height: TraceSpace.xl),
                      _labelled(
                        context,
                        'Amount',
                        _tappableRow(
                          context,
                          _quantity == null || _quantityUnit == null
                              ? 'None'
                              : QuantityGrammar.format(
                                  _quantity!, _quantityUnit!),
                          muted: _quantity == null,
                          mono: _quantity != null,
                          onTap: _pickQuantity,
                        ),
                      ).reveal(5),
                      const SizedBox(height: TraceSpace.xl),
                      _labelled(context, 'Note (optional)', _noteBox(context))
                          .reveal(6),
                      // Proof is deliberately absent in Phase 1. Git and
                      // screenshot capture need real integrations, and a row
                      // that does nothing is worse than no row.
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final c = context.traceColors;
    return Padding(
      // The back chevron's own padding makes up the rest of the left gutter.
      padding: EdgeInsets.fromLTRB(
        context.gutter - TraceSpace.sm,
        TraceSpace.sm,
        context.gutter,
        TraceSpace.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(TraceSpace.sm),
              child: Icon(Icons.chevron_left_rounded,
                  size: 26, color: c.textPrimary),
            ),
          ),
          PressScale(
            onTap: _title.trim().isEmpty ? null : _save,
            // Brightens as the title fills in rather than switching on.
            child: AnimatedOpacity(
              opacity: _title.trim().isEmpty ? 0.35 : 1,
              duration: TraceMotion.base,
              child: AnimatedSwitcher(
                duration: TraceMotion.base,
                switchInCurve: TraceMotion.emphasizedDecelerate,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: TraceButton.labelTransition,
                child: Text(
                  _saving ? 'Saving…' : 'Save',
                  key: ValueKey(_saving),
                  style: TraceText.button.copyWith(color: c.navy),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelled(BuildContext context, String label, Widget child) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: TraceSpace.sm),
        child,
      ],
    );
  }

  Widget _categoryRow(BuildContext context) {
    final c = context.traceColors;
    return PressScale(
      onTap: () => _pickCategory(context),
      child: Container(
        padding: const EdgeInsets.all(TraceSpace.md),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(TraceRadius.card),
        ),
        child: Row(
          children: [
            CategoryGlyph(
              category: _category,
              size: 28,
              // Pairs with the row that opened this screen. Absent when adding,
              // since there is no row to fly from.
              heroTag: widget.entryId == null
                  ? null
                  : 'entry-glyph-${widget.entryId}',
            ),
            const SizedBox(width: TraceSpace.md),
            Expanded(
              child: Text(
                _category.title,
                style: TraceText.body.copyWith(color: c.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _tappableRow(
    BuildContext context,
    String value, {
    required VoidCallback onTap,
    bool muted = false,
    bool mono = false,
  }) {
    final c = context.traceColors;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.md,
          vertical: TraceSpace.lg,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(TraceRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: (mono ? TraceText.mono : TraceText.body).copyWith(
                  color: muted ? c.textSecondary : c.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _noteBox(BuildContext context) {
    final c = context.traceColors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(TraceRadius.card),
      ),
      padding: const EdgeInsets.all(TraceSpace.md),
      child: TextField(
        controller: _noteController,
        maxLines: 4,
        minLines: 3,
        style: TraceText.body.copyWith(color: c.textPrimary),
        decoration: InputDecoration.collapsed(
          hintText: 'Anything worth remembering.',
          hintStyle: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }

  // ── Pickers ─────────────────────────────────────────────────────────────

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showTraceSheet<Category>(
      context: context,
      builder: (context) => _PickerSheet(
        title: 'Category',
        children: [
          for (final cat in Category.values)
            _PickerRow(
              leading: CategoryGlyph(category: cat, size: 28),
              label: cat.title,
              selected: cat == _category,
              onTap: () => Navigator.of(context).pop(cat),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  // Pickers return a record, so "chose None" (`(id: null)`) and "dismissed
  // the sheet" (null) stay different answers. A bare `String?` made a swipe
  // down unlink the project.

  Future<void> _pickProject(BuildContext context) async {
    final projects = ref.read(projectsProvider).value ?? const [];
    final picked = await showTraceSheet<({String? id})>(
      context: context,
      builder: (context) => _PickerSheet(
        title: 'Project',
        children: [
          _PickerRow(
            label: 'None',
            selected: _projectId == null,
            onTap: () => Navigator.of(context).pop((id: null)),
          ),
          for (final p in projects)
            _PickerRow(
              label: p.name,
              selected: p.id == _projectId,
              onTap: () => Navigator.of(context).pop((id: p.id)),
            ),
        ],
      ),
    );
    if (mounted && picked != null) setState(() => _projectId = picked.id);
  }

  Future<void> _pickBook(BuildContext context) async {
    final books = ref.read(booksProvider).value ?? const [];
    final picked = await showTraceSheet<({String? id})>(
      context: context,
      builder: (context) => _PickerSheet(
        title: 'Book',
        children: [
          _PickerRow(
            label: 'None',
            selected: _bookId == null,
            onTap: () => Navigator.of(context).pop((id: null)),
          ),
          for (final b in books)
            _PickerRow(
              label: b.title,
              selected: b.id == _bookId,
              onTap: () => Navigator.of(context).pop((id: b.id)),
            ),
        ],
      ),
    );
    if (mounted && picked != null) setState(() => _bookId = picked.id);
  }

  /// Duration is typed, not dialled.
  ///
  /// Reuses [DurationGrammar], so "2h 34m" works the same here as it does in
  /// Quick Add — one grammar, learned once.
  Future<void> _pickDuration() async {
    final picked = await _typedValue<Duration>(
      title: 'Duration',
      hint: 'e.g. 2h 34m',
      initial: _duration == null
          ? ''
          : formatDuration(_duration!, DurationFormat.human),
      parse: (v) => DurationGrammar.find(v)?.duration,
    );
    if (mounted && picked != null) setState(() => _duration = picked.value);
  }

  /// Pages, distance, sessions — typed through [QuantityGrammar], like Quick
  /// Add. Pages logged against a book move its bookmark.
  Future<void> _pickQuantity() async {
    final picked = await _typedValue<QuantityMatch>(
      title: 'Amount',
      hint: 'e.g. 27 pages',
      initial: _quantity == null || _quantityUnit == null
          ? ''
          : QuantityGrammar.format(_quantity!, _quantityUnit!),
      parse: QuantityGrammar.find,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _quantity = picked.value?.value;
      _quantityUnit = picked.value?.unit;
    });
  }

  /// A one-field sheet for a typed value.
  ///
  /// Returns null when dismissed or when the text does not parse, so neither
  /// changes anything. `(value: null)` means clear: from the None row, or from
  /// submitting an empty field.
  Future<({T? value})?> _typedValue<T extends Object>({
    required String title,
    required String hint,
    required String initial,
    required T? Function(String) parse,
  }) async {
    final controller = TextEditingController(text: initial);

    final result = await showTraceSheet<({T? value})>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final c = context.traceColors;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _PickerSheet(
            title: title,
            children: [
              Padding(
                padding: const EdgeInsets.all(TraceSpace.gutter),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: TraceText.body.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TraceText.body.copyWith(color: c.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TraceRadius.input),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TraceRadius.input),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) {
                      Navigator.of(context).pop((value: null));
                      return;
                    }
                    final parsed = parse(v);
                    Navigator.of(context)
                        .pop(parsed == null ? null : (value: parsed));
                  },
                ),
              ),
              _PickerRow(
                label: 'None',
                onTap: () => Navigator.of(context).pop((value: null)),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
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
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: TraceText.body.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TraceSpace.gutter,
                TraceSpace.xl,
                TraceSpace.gutter,
                TraceSpace.md,
              ),
              child: Text(
                title.toUpperCase(),
                style: TraceText.sectionLabel.copyWith(color: c.textSecondary),
              ),
            ),
            ...children,
            const SizedBox(height: TraceSpace.md),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.onTap,
    this.leading,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.gutter,
          vertical: TraceSpace.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: TraceSpace.md),
            ],
            Expanded(
              child: Text(
                label,
                style: TraceText.body.copyWith(color: c.textPrimary),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: c.navy),
          ],
        ),
      ),
    );
  }
}
