import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';
import 'press_scale.dart';

/// `Today · Timeline · [+] · Projects · More`
///
/// The centre `+` is navy and ~44pt: prominent, not oversized. Its rotation is
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

  static const _destinations = <({IconData icon, IconData active, String label})>[
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

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: TraceSize.navBar,
          child: Row(
            children: [
              _tab(context, 0),
              _tab(context, 1),
              _plusButton(context),
              _tab(context, 2),
              _tab(context, 3),
            ],
          ),
        ),
      ),
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
            Icon(
              selected ? d.active : d.icon,
              size: 20,
              color: selected ? c.textPrimary : c.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              d.label,
              style: TraceText.sectionLabel.copyWith(
                fontSize: 9,
                letterSpacing: 0.4,
                color: selected ? c.textPrimary : c.textSecondary,
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
      width: TraceSize.navPlus + TraceSpace.lg,
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
              child: Icon(Icons.add_rounded, size: 24, color: c.onNavy),
            ),
          ),
        ),
      ),
    );
  }
}
