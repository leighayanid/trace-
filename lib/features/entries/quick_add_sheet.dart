import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/parser/entry_parser.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/save_sweep.dart';
import '../../shared/widgets/trace_button.dart';
import 'entry_draft.dart';
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

  /// The cascade inside the sheet starts once the sheet has mostly risen —
  /// the emphasized curve covers most of the distance in the first third.
  static const _afterRise = Duration(milliseconds: 90);

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
    HapticFeedback.selectionClick();
    setState(() => _parsed = ref.read(entryParserProvider).parse(text));
  }

  void _back() => setState(() => _parsed = null);

  Future<void> _save() async {
    final parsed = _parsed;
    if (parsed == null || _saving) return;
    setState(() => _saving = true);

    // The sweep is the acknowledgement: let it finish crossing before the
    // sheet leaves, however quickly the write returns.
    await Future.wait([
      ref.read(entryRepositoryProvider).create(EntryDraft.fromParsed(parsed)),
      Future<void>.delayed(TraceMotion.base),
    ]);
    if (!mounted) return;

    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final route = ModalRoute.of(context)!.animation!;

    // Expands to the full screen so the blur has something to cover; the sheet
    // itself is bottom-aligned within it. The empty SizedBox under the filter
    // takes part in no hit test, so taps above the sheet still reach the
    // barrier and dismiss.
    return Stack(
      fit: StackFit.expand,
      children: [
        // The blur is driven by the sheet's own route animation, so the screen
        // behind recedes as the sheet rises, comes back into focus as it
        // leaves, and follows a finger dragging it down in between.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: route,
            builder: (context, _) {
              final sigma = 12 * Curves.easeOut.transform(route.value);
              return BackdropFilter(
                enabled: sigma > 0.05,
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.expand(),
              );
            },
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
    final stageKey = ValueKey(_parsed == null ? 'input' : 'confirm');

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
                  // The signature transition: the sentence dissolves upward
                  // out of focus, and the structured entry resolves in its
                  // place line by line.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      reverseDuration: const Duration(milliseconds: 260),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) => _StageTransition(
                        animation: animation,
                        leaving: child.key != stageKey,
                        child: child,
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
    // Close on the input stage, back on the confirm stage: the glyph turns
    // between the two so the change of meaning is visible.
    return Align(
      alignment: Alignment.centerLeft,
      child: PressScale(
        onTap: () => _parsed == null ? Navigator.of(context).pop() : _back(),
        child: Padding(
          padding: const EdgeInsets.all(TraceSpace.xs),
          child: AnimatedSwitcher(
            duration: TraceMotion.base,
            switchInCurve: TraceMotion.emphasizedDecelerate,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: RotationTransition(
                turns: Tween(begin: -0.125, end: 0.0).animate(animation),
                child: child,
              ),
            ),
            child: Icon(
              _parsed == null ? Icons.close_rounded : Icons.arrow_back_rounded,
              key: ValueKey(_parsed == null),
              color: _white,
              size: 22,
            ),
          ),
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
          ).reveal(0, focus: true, delay: _afterRise),
          const SizedBox(height: TraceSpace.xs),
          Text(
            "Just type it. I'll figure it out.",
            style: TraceText.rowSubtitle.copyWith(color: _muted),
          ).reveal(1, delay: _afterRise),
          const SizedBox(height: TraceSpace.xxl),
          _field().reveal(2, delay: _afterRise),
          const SizedBox(height: TraceSpace.xxl),
          Text(
            'QUICK SUGGESTIONS',
            style: TraceText.sectionLabel.copyWith(color: _muted),
          ).reveal(3, delay: _afterRise),
          const SizedBox(height: TraceSpace.md),
          Wrap(
            spacing: TraceSpace.sm,
            runSpacing: TraceSpace.sm,
            children: [
              for (var i = 0; i < _suggestions.length; i++)
                _chip(
                  _suggestions[i],
                ).reveal(4, delay: _afterRise + TraceMotion.chipStagger * i),
            ],
          ),
          const SizedBox(height: TraceSpace.xxl),
          _primaryButton('Continue', onTap: _continue).reveal(
            5,
            delay: _afterRise + TraceMotion.chipStagger * _suggestions.length,
          ),
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

  Widget _chip(String label) {
    return PressScale(
      scale: 0.95,
      onTap: () {
        HapticFeedback.selectionClick();
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
    );
  }

  Widget _primaryButton(String label, {required VoidCallback onTap}) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: TraceSize.button,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(TraceRadius.button),
        ),
        child: AnimatedSwitcher(
          duration: TraceMotion.base,
          switchInCurve: TraceMotion.emphasizedDecelerate,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: TraceButton.labelTransition,
          child: Text(
            label,
            key: ValueKey(label),
            style: TraceText.button.copyWith(color: _ink),
          ),
        ),
      ),
    );
  }

  // ── Stage 2: the structured entry ───────────────────────────────────────

  /// Resolves line by line, top to bottom, the way the parser reads the
  /// sentence: first what kind of thing it was, then what, then how much.
  Widget _confirmStage(ParsedEntry p) {
    // Leaves the old stage time to clear before the first line lands.
    const start = Duration(milliseconds: 120);

    return SingleChildScrollView(
      key: const ValueKey('confirm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uncertainty is carried by contrast, not hue: a recognised category
          // sits back in muted, an assumed one steps forward in white. An
          // amber warning colour would be a fifth colour in a palette that
          // allows monochrome and navy only.
          //
          // The label's tracking tightens as it appears — the same gesture as
          // the splash wordmark, so the category reads as being *stamped*.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 7.0, end: 2.4),
            duration: const Duration(milliseconds: 700),
            curve: TraceMotion.emphasizedDecelerate,
            builder: (context, spacing, _) => Text(
              p.category.label,
              style: TraceText.sectionLabel.copyWith(
                color: p.matchedCategory ? _muted : _white,
                letterSpacing: spacing,
              ),
            ),
          ).reveal(0, delay: start),
          const SizedBox(height: TraceSpace.md),
          Text(
            p.title.isEmpty ? p.raw : p.title,
            style: TraceText.screenTitle.copyWith(color: _white),
          ).reveal(1, focus: true, delay: start),
          const SizedBox(height: TraceSpace.lg),
          if (p.duration != null)
            MonoDuration(
              p.duration!,
              format: DurationFormat.human,
              style: TraceText.monoStat,
              color: _white,
              delay: start + TraceMotion.cascade * 2,
            ).reveal(2, delay: start),
          if (p.quantity != null && p.quantityUnit != null)
            Text(
              QuantityGrammar.format(p.quantity!, p.quantityUnit!),
              style: TraceText.monoStat.copyWith(color: _white),
            ).reveal(2, delay: start),
          if (p.duration == null && p.quantity == null)
            Text(
              'No duration',
              style: TraceText.rowSubtitle.copyWith(color: _muted),
            ).reveal(2, delay: start),
          if (!p.matchedCategory) ...[
            const SizedBox(height: TraceSpace.lg),
            Text(
              "I wasn't sure of the category — tap Edit details to set it.",
              style: TraceText.rowSubtitle.copyWith(color: _white),
            ).reveal(3, delay: start),
          ],
          const SizedBox(height: TraceSpace.xxxl),
          _primaryButton(
            _saving ? 'Saving…' : 'Save',
            onTap: _save,
          ).reveal(4, delay: start),
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
          ).reveal(5, delay: start),
        ],
      ),
    );
  }
}

/// How the two stages hand over.
///
/// Arriving, the stage itself only fades up — its lines carry their own
/// cascade. Leaving, it lifts, blurs and fades together, so the sentence reads
/// as dissolving *into* the entry rather than being swapped for it.
class _StageTransition extends StatelessWidget {
  const _StageTransition({
    required this.animation,
    required this.leaving,
    required this.child,
  });

  final Animation<double> animation;
  final bool leaving;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = TraceMotion.reduced(context);

    // One structure for both roles. The current stage becomes the leaving one
    // mid-life; if its wrapper changed shape then, the stage would be remounted
    // and replay its own entrance on the way out.
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        var opacity = Curves.easeOut.transform(t);
        var lift = 0.0;
        var sigma = 0.0;
        if (leaving) {
          // t runs 1 → 0 as it leaves; `gone` runs 0 → 1, accelerating.
          final gone = TraceMotion.emphasizedAccelerate.transform(1 - t);
          opacity = 1 - gone;
          if (!still) {
            lift = -24 * gone;
            sigma = 8 * gone;
          }
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, lift),
            child: ImageFiltered(
              enabled: sigma > 0.05,
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
