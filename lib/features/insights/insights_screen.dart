import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TraceSpace.gutter,
            TraceSpace.lg,
            TraceSpace.gutter,
            TraceSpace.xxxl,
          ),
          children: [
            Text('Insights',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.xl),
            _segmented(context, ref, range),
            const SizedBox(height: TraceSpace.section),
            ...data.when(
              data: (d) => _content(context, d, range),
              loading: () => const [SizedBox.shrink()],
              error: (_, _) => [
                Text("Couldn't compute insights.",
                    style: TraceText.body.copyWith(color: c.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented(BuildContext context, WidgetRef ref, InsightsRange range) {
    final c = context.traceColors;
    final notifier = ref.read(insightsRangeProvider.notifier);

    Widget tab(String label, InsightsRange value) {
      final selected = range == value;
      return Expanded(
        child: PressScale(
          onTap: () => notifier.select(value),
          child: AnimatedContainer(
            duration: TraceMotion.fast,
            curve: TraceMotion.standard,
            padding: const EdgeInsets.symmetric(vertical: TraceSpace.sm),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(TraceRadius.button - 2),
            ),
            child: Text(
              label,
              style: TraceText.rowSubtitle.copyWith(
                color: selected ? c.onNavy : c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.navyLight,
        borderRadius: BorderRadius.circular(TraceRadius.button),
      ),
      child: Row(
        children: [
          tab('This Month', InsightsRange.month),
          tab('This Year', InsightsRange.year),
        ],
      ),
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
        ),
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
      ),
      const SizedBox(height: TraceSpace.md),
      for (var i = 0; i < Category.values.length; i++)
        ConsistencyRow(
          label: Category.values[i].title,
          days: d.presenceByCategory[Category.values[i]]!,
        ).animate().fadeIn(
              delay: TraceMotion.rowStagger * i,
              duration: TraceMotion.base,
            ),
      const SizedBox(height: TraceSpace.section),
      const SectionLabel('Time spent'),
      const SizedBox(height: TraceSpace.lg),
      _timeSpent(context, d),
      const SizedBox(height: TraceSpace.section),
      const SectionLabel('Quick stats'),
      const SizedBox(height: TraceSpace.md),
      _quickStats(context, d),
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
          centerTop: '${hours}h',
          centerBottom: 'TOTAL',
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
                      Text('${(d.share(cat) * 100).round()}%',
                          style: TraceText.monoSmall
                              .copyWith(color: c.textSecondary)),
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

    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Row(
            children: [
              Icon(icon, size: 15, color: c.textSecondary),
              const SizedBox(width: TraceSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TraceText.mono.copyWith(color: c.textPrimary)),
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
        stat(Icons.grid_view_outlined, '${d.projectCount}', 'PROJECTS'),
        stat(Icons.menu_book_outlined, '${d.bookCount}', 'BOOKS'),
        stat(Icons.public_outlined, '${d.exploreTopics}', 'TOPICS'),
      ],
    );
  }
}
