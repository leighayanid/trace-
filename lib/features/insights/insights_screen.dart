import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/period_stepper.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_segmented.dart';
import 'insights_providers.dart';
import 'widgets/consistency_row.dart';
import 'widgets/donut_chart.dart';

/// Patterns, not a scoreboard.
///
/// Deliberately two charts and a short stat row — the brief warns against
/// overloading this screen, and every extra chart here costs the calm.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final range = ref.watch(insightsRangeProvider);
    final data = ref.watch(insightsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RevealScope(
          delay: const Duration(milliseconds: 140),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              TraceSpace.lg,
              context.gutter,
              TraceSpace.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Insights',
                        style: TraceText.screenTitle
                            .copyWith(color: c.textPrimary))
                    .reveal(0),
                const SizedBox(height: TraceSpace.xl),
                _segmented(context, ref, range).reveal(1),
                const SizedBox(height: TraceSpace.lg),
                _stepper(ref, range).reveal(2),
                const SizedBox(height: TraceSpace.section),
                // Keeps showing the old period while the new one computes, then
                // cross-fades — rather than blanking to a loading state between.
                data.when(
                  skipLoadingOnReload: true,
                  data: (d) => AnimatedSwitcher(
                    duration: TraceMotion.page,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey((range, d.from)),
                      // A fresh scope per period, so switching month to year
                      // redraws the charts and replays the cascade for the
                      // new numbers.
                      child: RevealScope(
                        delay: _contentDelay,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _content(context, d, range),
                        ),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => Text("Couldn't compute insights.",
                      style: TraceText.body.copyWith(color: c.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The period's content follows the title and the range control in.
  static const _contentDelay = Duration(milliseconds: 250);

  /// When a chart in cascade slot [order] starts drawing: once its section
  /// has faded in.
  static Duration _drawAt(int order) =>
      _contentDelay +
      TraceMotion.cascade * order +
      const Duration(milliseconds: 150);

  Widget _segmented(BuildContext context, WidgetRef ref, InsightsRange range) {
    return TraceSegmented<InsightsRange>(
      segments: const {
        InsightsRange.month: 'Month',
        InsightsRange.year: 'Year',
      },
      selected: range,
      onSelect: ref.read(insightsRangeProvider.notifier).select,
    );
  }

  Widget _stepper(WidgetRef ref, InsightsRange range) {
    final start = ref.watch(insightsPeriodProvider);
    final period = ref.read(insightsPeriodProvider.notifier);
    return PeriodStepper(
      label: DateFormat(range == InsightsRange.month ? 'MMMM yyyy' : 'yyyy')
          .format(start),
      direction: period.direction,
      onPrevious: period.previous,
      onNext: period.isCurrent ? null : period.next,
    );
  }

  List<Widget> _content(
      BuildContext context, InsightsData d, InsightsRange range) {
    final c = context.traceColors;

    if (d.totalSeconds == 0 && d.totalPages == 0) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TraceSpace.xxxl),
          child: Center(
            child: Text('Nothing recorded in this period.',
                style: TraceText.body.copyWith(color: c.textSecondary)),
          ),
        ).reveal(0),
      ];
    }

    return [
      SectionLabel(
        'Consistency',
        trailing: Text(
          range == InsightsRange.month
              ? DateFormat('MMMM').format(d.from)
              : DateFormat('yyyy').format(d.from),
          style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
        ),
      ).reveal(0),
      const SizedBox(height: TraceSpace.md),
      // Each row's dots begin rippling once the row has landed, so the four
      // months are written out one after another rather than all at once.
      for (var i = 0; i < Category.values.length; i++)
        ConsistencyRow(
          label: Category.values[i].title,
          days: d.presenceByCategory[Category.values[i]]!,
          delay: _drawAt(1 + i),
        ).reveal(1 + i),
      const SizedBox(height: TraceSpace.section),
      const SectionLabel('Time spent').reveal(5),
      const SizedBox(height: TraceSpace.lg),
      _timeSpent(context, d).reveal(6),
      const SizedBox(height: TraceSpace.section),
      const SectionLabel('Quick stats').reveal(7),
      const SizedBox(height: TraceSpace.md),
      _quickStats(context, d).reveal(8),
    ];
  }

  Widget _timeSpent(BuildContext context, InsightsData d) {
    final c = context.traceColors;

    // Category separation by tint, not by four arbitrary hues. The brief rules
    // out bright per-category colours, so this is one navy stepped in opacity.
    final shades = <Category, Color>{
      Category.build: c.navy,
      Category.read: c.navy.withValues(alpha: 0.72),
      Category.explore: c.navy.withValues(alpha: 0.48),
      Category.life: c.navy.withValues(alpha: 0.28),
    };

    final hours = (d.totalSeconds / 3600).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DonutChart(
          slices: [
            for (final cat in Category.values)
              DonutSlice(
                label: cat.title,
                value: (d.secondsByCategory[cat] ?? 0).toDouble(),
                color: shades[cat]!,
              ),
          ],
          centerValue: hours,
          centerSuffix: 'h',
          centerBottom: 'TOTAL',
          delay: _drawAt(6),
        ),
        const SizedBox(width: TraceSpace.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cat in Category.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: shades[cat],
                        ),
                      ),
                      const SizedBox(width: TraceSpace.sm),
                      Expanded(
                        child: Text(cat.title,
                            style: TraceText.rowSubtitle
                                .copyWith(color: c.textPrimary)),
                      ),
                      MonoValue(
                        (d.share(cat) * 100).round(),
                        suffix: '%',
                        style: TraceText.monoSmall,
                        color: c.textSecondary,
                        delay: _drawAt(6),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickStats(BuildContext context, InsightsData d) {
    final c = context.traceColors;

    Widget stat(IconData icon, int value, String label) => Expanded(
          child: Row(
            children: [
              Icon(icon, size: 15, color: c.textSecondary),
              const SizedBox(width: TraceSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MonoValue(value, color: c.textPrimary, delay: _drawAt(8)),
                  Text(label,
                      style: TraceText.sectionLabel
                          .copyWith(color: c.textSecondary, fontSize: 9)),
                ],
              ),
            ],
          ),
        );

    return Row(
      children: [
        stat(Icons.grid_view_outlined, d.projectCount, 'PROJECTS'),
        stat(Icons.menu_book_outlined, d.bookCount, 'BOOKS'),
        stat(Icons.public_outlined, d.exploreTopics, 'TOPICS'),
      ],
    );
  }
}
