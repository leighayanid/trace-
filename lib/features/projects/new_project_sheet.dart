import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/trace_sheet.dart';
import '../../core/parser/duration_grammar.dart';
import 'project_providers.dart';

/// Creates a project. Name is the only required field.
///
/// The target is optional and explicitly labelled as the thing that unlocks a
/// percentage — so a progress bar is always something the user opted into.
class NewProjectSheet extends ConsumerStatefulWidget {
  const NewProjectSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showTraceSheet<void>(
      context: context,
      builder: (_) => const NewProjectSheet(),
    );
  }

  @override
  ConsumerState<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends ConsumerState<NewProjectSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _target = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    await ref.read(projectRepositoryProvider).create(
          name: name,
          description: _description.text,
          target: DurationGrammar.find(_target.text)?.duration,
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
                Text('NEW PROJECT',
                    style: TraceText.sectionLabel
                        .copyWith(color: c.textSecondary)),
                const SizedBox(height: TraceSpace.xl),
                _field(context, _name, 'Name', autofocus: true),
                const SizedBox(height: TraceSpace.lg),
                _field(context, _description, 'Description (optional)'),
                const SizedBox(height: TraceSpace.lg),
                _field(context, _target, 'Target, e.g. 40h (optional)'),
                const SizedBox(height: TraceSpace.sm),
                Text(
                  'A target is what makes a percentage mean something. '
                  'Without one, only tracked time is shown.',
                  style: TraceText.rowSubtitle
                      .copyWith(color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: TraceSpace.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: PressScale(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Text(
                        _saving ? 'Saving…' : 'Create',
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
