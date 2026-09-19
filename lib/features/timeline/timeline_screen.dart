import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/day_picker.dart';
import '../../shared/widgets/entry_row.dart';
import '../../shared/widgets/period_stepper.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/reveal.dart';
import '../entries/entry_providers.dart';
import '../entries/entry_repository.dart';
import '../search/search_screen.dart';
import 'timeline_providers.dart';

/// The primary history view.
///
/// A readable record rather than a calendar grid — months are paged through, and
/// each day is a block you can actually read months later.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final groups = ref.watch(monthTimelineProvider);
    final month = ref.watch(visibleMonthProvider);
    final direction = ref.watch(monthDirectionProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                TraceSpace.lg,
                context.gutter,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Timeline',
                      style:
                          TraceText.screenTitle.copyWith(color: c.textPrimary)),
                  Row(
                    children: [
                      PressScale(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(TraceSpace.xs),
                          child: Icon(Icons.search_rounded,
                              size: 20, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: TraceSpace.sm),
                  // Jumps to a month without stepping through every one
                  // between.
                  PressScale(
                    onTap: () async {
                      final today = DateTime.parse(ref.read(currentDayProvider));
                      final picked = await showDayPicker(
                        context,
                        selected: month,
                        today: today,
                        title: 'Go to',
                      );
                      if (picked != null) {
                        ref
                            .read(visibleMonthProvider.notifier)
                            .showMonthOf(picked);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.xs),
                      child: Icon(Icons.calendar_today_outlined,
                          size: 18, color: c.textSecondary),
                    ),
                  ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: TraceSpace.lg),
            _monthStepper(context, ref, month, direction),
            const SizedBox(height: TraceSpace.sm),
            Expanded(
              // Months slide along the horizontal axis in the direction of the
              // arrow pressed, so paging back feels like moving back.
              child: PageTransitionSwitcher(
                duration: TraceMotion.page,
                reverse: direction < 0,
                transitionBuilder: (child, primary, secondary) =>
                    SharedAxisTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: c.bg,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(DateFormat('yyyy-MM').format(month)),
                  // A fresh scope per month: each month's days cascade in as
                  // it arrives, and only then.
                  child: RevealScope(
                    delay: const Duration(milliseconds: 120),
                    child: groups.when(
                      data: (data) => data.isEmpty
                          ? _empty(context, month)
                          : _list(context, data),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => _error(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthStepper(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
    int direction,
  ) {
    final notifier = ref.read(visibleMonthProvider.notifier);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.gutter),
      child: PeriodStepper(
        label: DateFormat('MMMM yyyy').format(month),
        direction: direction,
        onPrevious: notifier.previous,
        onNext: notifier.isCurrent ? null : notifier.next,
      ),
    );
  }

  Widget _list(BuildContext context, List<DayGroup> groups) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        TraceSpace.md,
        context.gutter,
        TraceSpace.xxxl,
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) => _DayBlock(
        group: groups[i],
      ).reveal(i.clamp(0, 7), key: ValueKey(groups[i].date)),
    );
  }

  Widget _empty(BuildContext context, DateTime month) {
    final c = context.traceColors;
    return Center(
      child: Text(
        'Nothing recorded in ${DateFormat('MMMM').format(month)}.',
        style: TraceText.body.copyWith(color: c.textSecondary),
      ).reveal(0),
    );
  }

  Widget _error(BuildContext context) {
    final c = context.traceColors;
    return Center(
      child: Text("Couldn't read the timeline.",
          style: TraceText.body.copyWith(color: c.textSecondary)),
    );
  }
}

/// One day: a mono date gutter on the left, that day's entries on the right.
class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.group});

  final DayGroup group;

  static const _gutterWidth = 34.0;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final date = DateTime.parse(group.date);

    final gutter = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('dd').format(date),
          style: TraceText.monoLarge.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('E').format(date),
          style: TraceText.sectionLabel.copyWith(
            color: c.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.xl),
      // The card sets the block's height; the gutter is laid over its left
      // edge so it has the full height to travel in while pinned.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _gutterWidth + TraceSpace.md),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(TraceRadius.card),
              ),
              padding: const EdgeInsets.symmetric(horizontal: TraceSpace.md),
              child: Column(
                children: [
                  for (var i = 0; i < group.entries.length; i++) ...[
                    if (i > 0) Divider(color: c.border, height: 1),
                    EntryRow(
                      category: group.entries[i].categoryEnum,
                      title: group.entries[i].title,
                      duration: group.entries[i].durationOrNull,
                      quantityLabel: group.entries[i].quantityLabel,
                      showChevron: false,
                      // Dozens of simultaneous tickers in a scrolling history
                      // would be noise; the value matters more than the motion.
                      animateValue: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gutterWidth,
            child: _StickyGutter(child: gutter),
          ),
        ],
      ),
    );
  }

}

/// A day's date that stays in view while you read that day.
///
/// As a long day scrolls up, its date pins to the top of the list and rides
/// down its own block; when the block's end arrives it is pushed out, fading
/// as it goes, and the next day's date takes over. You always know which day
/// you are reading without the dates ever stacking up.
///
/// Done in paint rather than layout — a [Flow] repositions the gutter on every
/// scroll tick without relaying out anything, so the list scrolls as cheaply
/// as it did without it.
class _StickyGutter extends StatelessWidget {
  const _StickyGutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      return Align(alignment: Alignment.topLeft, child: child);
    }
    return Flow(
      delegate: _StickyGutterDelegate(scrollable: scrollable, block: context),
      children: [child],
    );
  }
}

class _StickyGutterDelegate extends FlowDelegate {
  _StickyGutterDelegate({required this.scrollable, required this.block})
      : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext block;

  /// Where a pinned date sits, below the top edge of the list.
  static const _inset = TraceSpace.sm;

  /// Distance over which a date fades as its block's end pushes it out.
  static const _fade = 24.0;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      constraints.loosen();

  @override
  void paintChildren(FlowPaintingContext context) {
    final viewport = scrollable.context.findRenderObject();
    final box = block.findRenderObject();
    final child = context.getChildSize(0);
    if (viewport is! RenderBox || box is! RenderBox || child == null) {
      context.paintChild(0);
      return;
    }

    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final room = math.max(0.0, context.size.height - child.height);
    final pinned = (_inset - top).clamp(0.0, room);
    final span = math.min(_fade, room);
    final opacity = span <= 0 ? 1.0 : ((room - pinned) / span).clamp(0.0, 1.0);

    context.paintChild(
      0,
      transform: Matrix4.translationValues(0, pinned, 0),
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(_StickyGutterDelegate old) =>
      old.scrollable != scrollable || old.block != block;
}
