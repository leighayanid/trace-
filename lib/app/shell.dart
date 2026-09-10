import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/parser/entry_parser.dart';
import '../features/entries/add_entry_screen.dart';
import '../features/entries/quick_add_sheet.dart';
import '../shared/widgets/trace_nav_bar.dart';
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

class TraceShellState extends State<TraceShell>
    with TickerProviderStateMixin {
  late final AnimationController _plus = AnimationController(
    vsync: this,
    duration: TraceMotion.base,
  );

  /// Fades new tab content in on a destination change.
  ///
  /// Deliberately *not* an AnimatedSwitcher or PageTransitionSwitcher around
  /// the navigation shell: re-keying it to force a transition risks tearing down
  /// the IndexedStack that keeps each tab's scroll position and state. Driving
  /// opacity separately leaves the shell untouched.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: TraceMotion.base,
    value: 1,
  );

  @override
  void dispose() {
    _plus.dispose();
    _tabFade.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index != widget.navigationShell.currentIndex) {
      _tabFade
        ..value = 0
        ..forward();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> openQuickAdd() async {
    _plus.forward();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => QuickAddSheet(onEditDetails: _openDetails),
    );
    if (mounted) _plus.reverse();
  }

  void _openDetails(ParsedEntry parsed) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEntryScreen(parsed: parsed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _tabFade,
          curve: TraceMotion.standard,
        ),
        child: widget.navigationShell,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _plus,
        builder: (context, _) => TraceNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          plusTurns: _plus.value * 0.125,
          onPlus: openQuickAdd,
          onSelect: _select,
        ),
      ),
    );
  }
}
