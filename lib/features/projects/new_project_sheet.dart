import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/form_sheet.dart';
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
    return FormSheet(
      label: 'New project',
      saveLabel: 'Create',
      saving: _saving,
      onSave: _save,
      fields: [
        FieldBox(
          child: BareField(controller: _name, hint: 'Name', autofocus: true),
        ),
        FieldBox(
          child: BareField(
            controller: _description,
            hint: 'Description (optional)',
          ),
        ),
        FieldBox(
          note: 'A target is what makes a percentage mean something. '
              'Without one, only tracked time is shown.',
          child: BareField(
            controller: _target,
            hint: 'Target, e.g. 40h (optional)',
          ),
        ),
      ],
    );
  }
}
