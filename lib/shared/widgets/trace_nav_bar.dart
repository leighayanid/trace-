import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// `Today · Timeline · [+] · Projects · More`
///
/// The centre `+` is navy and ~48pt: prominent, not oversized. Its rotation is
/// driven externally by [plusTurns] so the Quick Add sheet and the `+ → ×` morph
/// share one controller rather than running two animations that drift apart.
class TraceNavBar extends StatelessWidget {
  const TraceNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onPlus,
    this.plusTurns = 0,
  });

  /// Index into the four destinations, skipping the centre `+`.
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onPlus;

  /// 0 = `+`, 0.125 = rotated 45° into `×`.
  final double plusTurns;

  static const _destinations =
      <({IconData icon, IconData active, String label})>[
    (
      icon: Icons.bookmark_outline_rounded,
      active: Icons.bookmark_rounded,
      label: 'Today'
    ),
    (
      icon: Icons.segment_rounded,
      active: Icons.segment_rounded,
      label: 'Timeline'
    ),
    (
      icon: Icons.grid_view_outlined,
      active: Icons.grid_view_rounded,
      label: 'Projects'
    ),
    (
      icon: Icons.more_horiz_rounded,
      active: Icons.more_horiz_rounded,
      label: 'More'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    // Labels follow the system text size, but only so far: past 1.3× five slots
    // have nowhere left to put the words, and the bar's height is fixed.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          // The bar spans the screen; the destinations do not. heightFactor
          // keeps Center from claiming the whole height the Scaffold offers.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: TraceSize.navMaxWidth),
              child: SizedBox(
                height: TraceSize.navBar,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Row(
                      children: [
                        _tab(context, 0),
                        _tab(context, 1),
                        _plusButton(context),
                        _tab(context, 2),
                        _tab(context, 3),
                      ],
                    ),
                    _indicator(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A short rule riding the bar's top hairline above the active tab — the
  /// hairline thickening where you are. It glides between tabs rather than
  /// jumping, so the eye follows the change instead of hunting for it.
  Widget _indicator(BuildContext context) {
    final c = context.traceColors;
    const width = 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final plusSlot = TraceSize.navPlus + TraceSpace.xl;
        final tabWidth = (constraints.maxWidth - plusSlot) / 4;
        // Tabs 2 and 3 sit to the right of the + slot.
        final centre = tabWidth * (currentIndex + 0.5) +
            (currentIndex >= 2 ? plusSlot : 0);

        return IgnorePointer(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: TraceMotion.emphasized,
                top: 0,
                left: centre - width / 2,
                width: width,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.textPrimary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(BuildContext context, int index) {
    final c = context.traceColors;
    final d = _destinations[index];
    final selected = index == currentIndex;

    return Expanded(
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Outline to filled cross-fades with a slight lift in scale, so
            // selecting a tab reads as the icon taking weight.
            AnimatedSwitcher(
              duration: TraceMotion.base,
              switchInCurve: TraceMotion.emphasizedDecelerate,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.86, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(
                selected ? d.active : d.icon,
                key: ValueKey(selected),
                size: 24,
                color: selected ? c.textPrimary : c.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            // Shrinks rather than clips on a narrow phone at a large text size.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: TraceSpace.xs),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: TraceMotion.base,
                  curve: TraceMotion.standard,
                  style: TraceText.navLabel.copyWith(
                    color: selected ? c.textPrimary : c.textSecondary,
                  ),
                  child: Text(d.label, maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plusButton(BuildContext context) {
    final c = context.traceColors;

    return SizedBox(
      width: TraceSize.navPlus + TraceSpace.xl,
      child: Center(
        child: PressScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onPlus();
          },
          child: Container(
            width: TraceSize.navPlus,
            height: TraceSize.navPlus,
            decoration: BoxDecoration(color: c.navy, shape: BoxShape.circle),
            child: RotationTransition(
              turns: AlwaysStoppedAnimation(plusTurns),
              child: Icon(Icons.add_rounded, size: 26, color: c.onNavy),
            ),
          ),
        ),
      ),
    );
  }
}
