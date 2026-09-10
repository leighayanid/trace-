import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/widgets/entry_row.dart';
import '../../shared/widgets/press_scale.dart';
import '../entries/entry_repository.dart';
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

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TraceSpace.gutter,
                TraceSpace.lg,
                TraceSpace.gutter,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Timeline',
                      style:
                          TraceText.screenTitle.copyWith(color: c.textPrimary)),
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: c.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: TraceSpace.lg),
            _monthStepper(context, ref, month),
            const SizedBox(height: TraceSpace.sm),
            Expanded(
              child: groups.when(
                data: (data) => data.isEmpty
                    ? _empty(context, month)
                    : _list(context, data),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => _error(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthStepper(BuildContext context, WidgetRef ref, DateTime month) {
    final c = context.traceColors;
    final notifier = ref.read(visibleMonthProvider.notifier);
    // Paging forward past the current month would only ever show emptiness.
    final canGoNext = !ref.read(visibleMonthProvider.notifier).isCurrent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TraceSpace.gutter),
      child: Row(
        children: [
          PressScale(
            onTap: notifier.previous,
            child: Padding(
              padding: const EdgeInsets.all(TraceSpace.xs),
              child: Icon(Icons.chevron_left_rounded,
                  size: 20, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: TraceSpace.sm),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: TraceText.categoryLabel.copyWith(color: c.textPrimary),
          ),
          const SizedBox(width: TraceSpace.sm),
          PressScale(
            onTap: canGoNext ? notifier.next : null,
            child: Padding(
              padding: const EdgeInsets.all(TraceSpace.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: canGoNext ? c.textSecondary : c.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<DayGroup> groups) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        TraceSpace.gutter,
        TraceSpace.md,
        TraceSpace.gutter,
        TraceSpace.xxxl,
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) => _DayBlock(group: groups[i], index: i),
    );
  }

  Widget _empty(BuildContext context, DateTime month) {
    final c = context.traceColors;
    return Center(
      child: Text(
        'Nothing recorded in ${DateFormat('MMMM').format(month)}.',
        style: TraceText.body.copyWith(color: c.textSecondary),
      ),
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
  const _DayBlock({required this.group, required this.index});

  final DayGroup group;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final date = DateTime.parse(group.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
          const SizedBox(width: TraceSpace.md),
          Expanded(
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
                      quantityLabel: _quantityLabel(group.entries[i]),
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
        ],
      ),
    ).animate().fadeIn(
          delay: TraceMotion.rowStagger * (index.clamp(0, 6)),
          duration: TraceMotion.base,
        );
  }

  static String? _quantityLabel(Entry e) {
    if (e.quantity == null || e.quantityUnit == null) return null;
    if (e.durationSecs != null) return null;
    return QuantityGrammar.format(e.quantity!, e.quantityUnit!);
  }
}
