import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/parser/duration_grammar.dart';
import '../../core/parser/entry_parser.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/category_glyph.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/save_sweep.dart';
import 'entry_providers.dart';

/// The confirmation form. Every field the parser proposed is editable here —
/// the parser suggests, the user decides.
class AddEntryScreen extends ConsumerStatefulWidget {
  const AddEntryScreen({super.key, required this.parsed, this.entryId});

  final ParsedEntry parsed;

  /// Set when editing an existing entry rather than creating one.
  final String? entryId;

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  late Category _category = widget.parsed.category;
  late String _title = widget.parsed.title;
  late Duration? _duration = widget.parsed.duration;
  late String? _projectId = widget.parsed.projectId;
  final _noteController = TextEditingController();
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
    final note = _noteController.text.trim();

    if (widget.entryId != null) {
      await repo.update(
        id: widget.entryId!,
        category: _category,
        title: _title,
        description: note.isEmpty ? null : note,
        duration: _duration,
        projectId: _projectId,
      );
    } else {
      final id = await repo.createFromParsed(
        widget.parsed.copyWith(
          category: _category,
          title: _title,
          duration: _duration,
          projectId: _projectId,
        ),
      );
      if (note.isNotEmpty) {
        await repo.update(id: id, description: note);
      }
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
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  0,
                  context.gutter,
                  TraceSpace.xxxl,
                ),
                children: [
                  Text(
                    widget.entryId == null ? 'Add Entry' : 'Edit Entry',
                    style: TraceText.screenTitle.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: TraceSpace.xl),
                  _categoryRow(context),
                  const SizedBox(height: TraceSpace.xl),
                  _labelled(
                    context,
                    'Title',
                    _TextRow(
                      value: _title,
                      hint: 'What was it?',
                      onChanged: (v) => setState(() => _title = v),
                    ),
                  ),
                  if (_category == Category.build) ...[
                    const SizedBox(height: TraceSpace.xl),
                    _labelled(
                      context,
                      'Project',
                      _tappableRow(
                        context,
                        projectName ?? 'None',
                        muted: projectName == null,
                        onTap: () => _pickProject(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: TraceSpace.xl),
                  _labelled(
                    context,
                    'Duration',
                    _tappableRow(
                      context,
                      _duration == null
                          ? 'None'
                          : formatDuration(_duration!, DurationFormat.human),
                      muted: _duration == null,
                      mono: _duration != null,
                      onTap: _pickDuration,
                    ),
                  ),
                  const SizedBox(height: TraceSpace.xl),
                  _labelled(context, 'Note (optional)', _noteBox(context)),
                  // Proof is deliberately absent in Phase 1. Git and screenshot
                  // capture need real integrations, and a row that does nothing
                  // is worse than no row.
                ],
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
            child: Opacity(
              opacity: _title.trim().isEmpty ? 0.35 : 1,
              child: Text(
                _saving ? 'Saving…' : 'Save',
                style: TraceText.button.copyWith(color: c.navy),
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
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: Colors.transparent,
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

  Future<void> _pickProject(BuildContext context) async {
    final projects = ref.read(projectsProvider).value ?? const [];
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet(
        title: 'Project',
        children: [
          _PickerRow(
            label: 'None',
            selected: _projectId == null,
            onTap: () => Navigator.of(context).pop(null),
          ),
          for (final p in projects)
            _PickerRow(
              label: p.name,
              selected: p.id == _projectId,
              onTap: () => Navigator.of(context).pop(p.id),
            ),
        ],
      ),
    );
    if (mounted) setState(() => _projectId = picked);
  }

  /// Duration is typed, not dialled.
  ///
  /// Reuses [DurationGrammar], so "2h 34m" works the same here as it does in
  /// Quick Add — one grammar, learned once.
  Future<void> _pickDuration() async {
    final controller = TextEditingController(
      text: _duration == null
          ? ''
          : formatDuration(_duration!, DurationFormat.human),
    );

    final result = await showModalBottomSheet<Duration?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = context.traceColors;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _PickerSheet(
            title: 'Duration',
            children: [
              Padding(
                padding: const EdgeInsets.all(TraceSpace.gutter),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: TraceText.body.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. 2h 34m',
                    hintStyle:
                        TraceText.body.copyWith(color: c.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TraceRadius.input),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(TraceRadius.input),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                  onSubmitted: (v) => Navigator.of(context).pop(
                    DurationGrammar.find(v)?.duration,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (mounted && result != null) setState(() => _duration = result);
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
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: c.navy),
          ],
        ),
      ),
    );
  }
}
