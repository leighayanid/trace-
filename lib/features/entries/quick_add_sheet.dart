import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/parser/entry_parser.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/save_sweep.dart';
import '../../shared/widgets/trace_button.dart';
import 'entry_providers.dart';

/// The fastest path from a thought to a saved entry.
///
/// Keyboard-first and single-field: the target is under five seconds from tap to
/// saved, so nothing here may require a second decision.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, required this.onEditDetails});

  /// Opens the full Add Entry form with the parsed result.
  final void Function(ParsedEntry parsed) onEditDetails;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  ParsedEntry? _parsed;
  bool _saving = false;

  // Fixed rather than theme-derived, and deliberately so: Quick Add is a navy
  // surface in both light and dark, the way the splash is always dark. It is a
  // moment, not a page — theming it would make it blend into whatever screen it
  // was opened from, which is the opposite of what it is for.
  static const _ink = Color(0xFF0B1F3A);
  static const _white = Color(0xFFF5F5F2);
  static const _muted = Color(0xFF8C9AAE);

  static const _suggestions = <String>[
    'Coded on a project',
    'Read a book',
    'Browsed the web',
    'Went for a walk',
    'Slept',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _continue() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _focus.unfocus();
    setState(() => _parsed = ref.read(entryParserProvider).parse(text));
  }

  void _back() => setState(() => _parsed = null);

  Future<void> _save() async {
    final parsed = _parsed;
    if (parsed == null || _saving) return;
    setState(() => _saving = true);

    await ref.read(entryRepositoryProvider).createFromParsed(parsed);
    if (!mounted) return;

    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    // Expands to the full screen so the blur has something to cover; the sheet
    // itself is bottom-aligned within it. The empty SizedBox under the filter
    // takes part in no hit test, so taps above the sheet still reach the
    // barrier and dismiss.
    return Stack(
      fit: StackFit.expand,
      children: [
        // The blur ramps in with the sheet rather than snapping on, so the
        // screen behind recedes instead of being replaced.
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 12),
            duration: TraceMotion.base,
            curve: TraceMotion.enter,
            builder: (context, sigma, _) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _sheet(context, insets),
        ),
      ],
    );
  }

  Widget _sheet(BuildContext context, double insets) {
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: const BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(TraceSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _closeRow(),
                  const SizedBox(height: TraceSpace.lg),
                  // The signature transition: the sentence dissolves upward and
                  // the structured entry resolves in its place.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: TraceMotion.base,
                      switchInCurve: TraceMotion.enter,
                      switchOutCurve: TraceMotion.exit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.06),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _parsed == null
                          ? _inputStage()
                          : _confirmStage(_parsed!),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _closeRow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () =>
            _parsed == null ? Navigator.of(context).pop() : _back(),
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.all(TraceSpace.xs),
          child: Icon(Icons.close_rounded, color: _white, size: 22),
        ),
      ),
    );
  }

  // ── Stage 1: the sentence ───────────────────────────────────────────────

  Widget _inputStage() {
    return SingleChildScrollView(
      key: const ValueKey('input'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What did you do?',
            style: TraceText.screenTitle.copyWith(color: _white),
          ),
          const SizedBox(height: TraceSpace.xs),
          Text(
            "Just type it. I'll figure it out.",
            style: TraceText.rowSubtitle.copyWith(color: _muted),
          ),
          const SizedBox(height: TraceSpace.xxl),
          _field(),
          const SizedBox(height: TraceSpace.xxl),
          Text(
            'QUICK SUGGESTIONS',
            style: TraceText.sectionLabel.copyWith(color: _muted),
          ),
          const SizedBox(height: TraceSpace.md),
          Wrap(
            spacing: TraceSpace.sm,
            runSpacing: TraceSpace.sm,
            children: [
              for (var i = 0; i < _suggestions.length; i++)
                _chip(_suggestions[i], i),
            ],
          ),
          const SizedBox(height: TraceSpace.xxl),
          _continueButton(),
        ],
      ),
    );
  }

  Widget _field() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: TraceText.body.copyWith(color: _white),
      cursorColor: _white,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _continue(),
      decoration: InputDecoration(
        hintText: 'e.g. coded for 2 hours on pds express',
        hintStyle: TraceText.body.copyWith(color: _muted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.lg,
          vertical: TraceSpace.lg,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TraceRadius.input),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TraceRadius.input),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        ),
      ),
    );
  }

  Widget _chip(String label, int index) {
    return GestureDetector(
      onTap: () {
        _controller.text = label.toLowerCase();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        _focus.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.md,
          vertical: TraceSpace.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TraceRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Text(
          label,
          style: TraceText.rowSubtitle.copyWith(color: _white),
        ),
      ),
    ).animate().fadeIn(
          delay: TraceMotion.chipStagger * index,
          duration: TraceMotion.fast,
        );
  }

  Widget _continueButton() {
    return GestureDetector(
      onTap: _continue,
      child: Container(
        height: TraceSize.button,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(TraceRadius.button),
        ),
        child: Text(
          'Continue',
          style: TraceText.button.copyWith(color: _ink),
        ),
      ),
    );
  }

  // ── Stage 2: the structured entry ───────────────────────────────────────

  Widget _confirmStage(ParsedEntry p) {
    return SingleChildScrollView(
      key: const ValueKey('confirm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uncertainty is carried by contrast, not hue: a recognised category
          // sits back in muted, an assumed one steps forward in white. An
          // amber warning colour would be a fifth colour in a palette that
          // allows monochrome and navy only.
          Text(
            p.category.label,
            style: TraceText.sectionLabel.copyWith(
              color: p.matchedCategory ? _muted : _white,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: TraceSpace.md),
          Text(
            p.title.isEmpty ? p.raw : p.title,
            style: TraceText.screenTitle.copyWith(color: _white),
          ),
          const SizedBox(height: TraceSpace.lg),
          if (p.duration != null)
            MonoDuration(
              p.duration!,
              format: DurationFormat.human,
              style: TraceText.monoStat,
              color: _white,
            ),
          if (p.quantity != null && p.quantityUnit != null)
            Text(
              QuantityGrammar.format(p.quantity!, p.quantityUnit!),
              style: TraceText.monoStat.copyWith(color: _white),
            ),
          if (p.duration == null && p.quantity == null)
            Text(
              'No duration',
              style: TraceText.rowSubtitle.copyWith(color: _muted),
            ),
          if (!p.matchedCategory) ...[
            const SizedBox(height: TraceSpace.lg),
            Text(
              "I wasn't sure of the category — tap Edit details to set it.",
              style: TraceText.rowSubtitle.copyWith(color: _white),
            ),
          ],
          const SizedBox(height: TraceSpace.xxxl),
          GestureDetector(
            onTap: _save,
            child: Container(
              height: TraceSize.button,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(TraceRadius.button),
              ),
              child: Text(
                _saving ? 'Saving…' : 'Save',
                style: TraceText.button.copyWith(color: _ink),
              ),
            ),
          ),
          const SizedBox(height: TraceSpace.xs),
          SaveSweep(active: _saving, color: _white),
          const SizedBox(height: TraceSpace.sm),
          Center(
            child: TraceButton.text(
              'Edit details',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditDetails(p);
              },
            ),
          ),
        ],
      ),
    );
  }
}
