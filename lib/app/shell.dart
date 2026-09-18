import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/entries/add_entry_screen.dart';
import '../features/entries/entry_draft.dart';
import '../features/entries/quick_add_sheet.dart';
import '../shared/widgets/trace_nav_bar.dart';
import '../shared/widgets/trace_sheet.dart';
import 'theme/theme.dart';

/// The persistent tab scaffold.
///
/// Owns the controller that drives both the Quick Add sheet and the nav `+`
/// rotating into a `×`. One controller, so the two can never drift apart.
class TraceShell extends StatefulWidget {
  const TraceShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<TraceShell> createState() => TraceShellState();

  /// Lets a descendant (the Today screen's `+ Add entry`) open the same sheet
  /// the nav bar opens, rather than duplicating the flow.
  static TraceShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<TraceShellState>();
}

class TraceShellState extends State<TraceShell> with TickerProviderStateMixin {
  /// The Quick Add sheet's own transition controller — handed to the sheet
  /// route, not merely started alongside it. So the `+` turning into a `×`
  /// tracks the sheet exactly: open, close, and a finger dragging it down
  /// halfway all turn the icon by the same amount.
  late final AnimationController _plus = AnimationController(
    vsync: this,
    duration: TraceMotion.sheet,
    reverseDuration: TraceMotion.sheetReverse,
  );

  late final Animation<double> _plusTurn = CurvedAnimation(
    parent: _plus,
    curve: TraceMotion.emphasizedDecelerate,
    reverseCurve: TraceMotion.emphasizedAccelerate.flipped,
  );

  /// Lifts new tab content in on a destination change.
  ///
  /// Deliberately *not* an AnimatedSwitcher or PageTransitionSwitcher around
  /// the navigation shell: re-keying it to force a transition risks tearing down
  /// the IndexedStack that keeps each tab's scroll position and state. Driving
  /// opacity and offset separately leaves the shell untouched.
  late final AnimationController _tab = AnimationController(
    vsync: this,
    duration: TraceMotion.tab,
    value: 1,
  );

  late final Animation<double> _tabFade = CurvedAnimation(
    parent: _tab,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  late final Animation<double> _tabLift = CurvedAnimation(
    parent: _tab,
    curve: TraceMotion.emphasizedDecelerate,
  );

  bool _quickAddOpen = false;

  @override
  void dispose() {
    _plus.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index != widget.navigationShell.currentIndex &&
        !TraceMotion.reduced(context)) {
      _tab.forward(from: 0);
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> openQuickAdd() async {
    // The shared controller can drive only one sheet at a time.
    if (_quickAddOpen) return;
    _quickAddOpen = true;
    try {
      await showTraceSheet<void>(
        context: context,
        controller: _plus,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (_) => QuickAddSheet(onEditDetails: _openDetails),
      );
    } finally {
      _quickAddOpen = false;
    }
  }

  void _openDetails(EntryDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddEntryScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _tab,
        child: widget.navigationShell,
        builder: (context, child) => Opacity(
          opacity: _tabFade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _tabLift.value) * 10),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _plusTurn,
        builder: (context, _) => TraceNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          plusTurns: _plusTurn.value * 0.125,
          onPlus: openQuickAdd,
          onSelect: _select,
        ),
      ),
    );
  }
}
