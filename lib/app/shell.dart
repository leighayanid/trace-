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
    with SingleTickerProviderStateMixin {
  late final AnimationController _plus = AnimationController(
    vsync: this,
    duration: TraceMotion.base,
  );

  @override
  void dispose() {
    _plus.dispose();
    super.dispose();
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
      body: widget.navigationShell,
      bottomNavigationBar: AnimatedBuilder(
        animation: _plus,
        builder: (context, _) => TraceNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          plusTurns: _plus.value * 0.125,
          onPlus: openQuickAdd,
          onSelect: (i) => widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
