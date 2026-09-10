import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/trace_button.dart';
import 'erase_controller.dart';

/// The last step before the record ends.
///
/// The word has to be typed. Everything else in TRACE is one tap and forgiving;
/// this is the one action that cannot be undone, so it is the one action that
/// asks you to mean it. No red, no warning triangle, no shouting — the friction
/// is the confirmation itself.
class EraseSheet extends ConsumerStatefulWidget {
  const EraseSheet({super.key});

  static const _word = 'DELETE';

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EraseSheet(),
    );
  }

  @override
  ConsumerState<EraseSheet> createState() => _EraseSheetState();
}

class _EraseSheetState extends ConsumerState<EraseSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed => _controller.text.trim() == EraseSheet._word;

  Future<void> _erase() async {
    if (!_confirmed || _busy) return;
    setState(() => _busy = true);

    try {
      final outcome = await ref.read(eraseControllerProvider).eraseEverything();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      if (outcome == EraseOutcome.erased) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _busy = false;
        _result = 'Deleted here. Your database could not be reached, so the '
            'deletion will finish on the next sync.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = 'Could not delete: $e';
      });
    }
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
          child: Padding(
            padding: const EdgeInsets.all(TraceSpace.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELETE ALL DATA',
                  style:
                      TraceText.sectionLabel.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: TraceSpace.md),
                Text(
                  'Every entry, project, book and note will be gone. This '
                  'cannot be undone, and TRACE keeps no backup of its own.',
                  style: TraceText.body
                      .copyWith(color: c.textPrimary, height: 1.5),
                ),
                const SizedBox(height: TraceSpace.xl),
                Text(
                  'Type ${EraseSheet._word} to confirm',
                  style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: TraceSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TraceSpace.md,
                    vertical: TraceSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(TraceRadius.input),
                  ),
                  child: TextField(
                    controller: _controller,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    style: TraceText.mono.copyWith(color: c.textPrimary),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: EraseSheet._word,
                      hintStyle:
                          TraceText.mono.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: TraceSpace.md),
                  Text(
                    _result!,
                    style: TraceText.rowSubtitle
                        .copyWith(color: c.textSecondary, height: 1.5),
                  ),
                ],
                const SizedBox(height: TraceSpace.xl),
                TraceButton(
                  _busy ? 'Deleting…' : 'Delete everything',
                  onPressed: _confirmed && !_busy ? _erase : null,
                ),
                const SizedBox(height: TraceSpace.sm),
                TraceButton.text(
                  'Cancel',
                  fullWidth: true,
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
