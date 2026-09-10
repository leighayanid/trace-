import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../core/parser/entry_parser.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/widgets/entry_row.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import '../entries/add_entry_screen.dart';
import '../entries/entry_providers.dart';
import '../entries/entry_repository.dart';
import 'one_line_sheet.dart';

/// The home screen, and the most important one in the app.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.onAddEntry});

  final VoidCallback? onAddEntry;

  static String _greeting(int hour) {
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final now = DateTime.now();
    final entriesAsync = ref.watch(todayEntriesProvider);
    final oneLine = ref.watch(oneLineProvider).value;
    final presence = ref.watch(presenceProvider);

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
            _header(context, now),
            const SizedBox(height: TraceSpace.xxl),
            _greetingBlock(context, now),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Today'),
            const SizedBox(height: TraceSpace.xs),
            ...entriesAsync.when(
              data: (entries) => entries.isEmpty
                  ? [_emptyState(context)]
                  : _entryList(context, ref, entries),
              // The list is local SQLite: it resolves within a frame. A spinner
              // here would flash rather than inform.
              loading: () => [const SizedBox(height: TraceSpace.xxxl)],
              error: (e, _) => [_errorState(context, e)],
            ),
            const SizedBox(height: TraceSpace.lg),
            TraceButton(
              '+ Add entry',
              icon: null,
              onPressed: onAddEntry,
            ).animate().fadeIn(
                  delay: const Duration(milliseconds: 320),
                  duration: TraceMotion.base,
                ),
            const SizedBox(height: TraceSpace.section),
            _presence(context, presence),
            const SizedBox(height: TraceSpace.section),
            _oneLine(context, oneLine),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DateTime now) {
    final c = context.traceColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('TRACE',
            style: TraceText.wordmarkSmall.copyWith(color: c.textPrimary)),
        Row(
          children: [
            Text(
              DateFormat('EEE, MMM d').format(now),
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
            const SizedBox(width: TraceSpace.sm),
            Icon(Icons.calendar_today_outlined,
                size: 15, color: c.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _greetingBlock(BuildContext context, DateTime now) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(now.hour),
            style: TraceText.greetingLine.copyWith(color: c.textSecondary)),
        const SizedBox(height: 2),
        Text('Leigh.',
            style: TraceText.greetingName.copyWith(color: c.textPrimary)),
      ],
    )
        .animate()
        .fadeIn(duration: TraceMotion.base)
        .slideY(begin: 0.15, end: 0, curve: TraceMotion.enter);
  }

  List<Widget> _entryList(
      BuildContext context, WidgetRef ref, List<Entry> entries) {
    final c = context.traceColors;
    return [
      for (var i = 0; i < entries.length; i++) ...[
        if (i > 0) Divider(color: c.border, height: 1),
        Dismissible(
          key: ValueKey(entries[i].id),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(context),
          onDismissed: (_) =>
              ref.read(entryRepositoryProvider).delete(entries[i].id),
          child: EntryRow(
            category: entries[i].categoryEnum,
            title: entries[i].title,
            duration: entries[i].durationOrNull,
            quantityLabel: _quantityLabel(entries[i]),
            // Flies into the category tile on the edit screen. Only Today sets
            // this: Timeline shares the same shell route, and a second row with
            // the same tag would be a duplicate Hero.
            heroTag: 'entry-glyph-${entries[i].id}',
            onTap: () => _edit(context, entries[i]),
          ),
        )
            .animate()
            .fadeIn(
              delay: TraceMotion.rowStagger * i,
              duration: TraceMotion.base,
            )
            .slideY(
              begin: 0.25,
              end: 0,
              delay: TraceMotion.rowStagger * i,
              duration: TraceMotion.base,
              curve: TraceMotion.enter,
            ),
      ],
    ];
  }

  static String? _quantityLabel(Entry e) {
    if (e.quantity == null || e.quantityUnit == null) return null;
    if (e.durationSecs != null) return null;
    return QuantityGrammar.format(e.quantity!, e.quantityUnit!);
  }

  Widget _deleteBackground(BuildContext context) {
    final c = context.traceColors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: TraceSpace.md),
      child: Icon(Icons.delete_outline_rounded, size: 20, color: c.textSecondary),
    );
  }

  void _edit(BuildContext context, Entry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEntryScreen(
          entryId: entry.id,
          parsed: ParsedEntry(
            raw: entry.title,
            category: entry.categoryEnum,
            title: entry.title,
            duration: entry.durationOrNull,
            quantity: entry.quantity,
            quantityUnit: entry.quantityUnit,
            projectId: entry.projectId,
            bookId: entry.bookId,
            matchedCategory: true,
          ),
        ),
      ),
    );
  }

  /// Absence, not failure. No prompt, no nudge, no empty-state illustration.
  Widget _emptyState(BuildContext context) {
    final c = context.traceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TraceSpace.xl),
      child: Text(
        'Nothing recorded yet.',
        style: TraceText.body.copyWith(color: c.textSecondary),
      ),
    ).animate().fadeIn(duration: TraceMotion.base);
  }

  Widget _errorState(BuildContext context, Object error) {
    final c = context.traceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TraceSpace.xl),
      child: Text(
        "Couldn't read today's entries.",
        style: TraceText.body.copyWith(color: c.textSecondary),
      ),
    );
  }

  Widget _presence(BuildContext context, double value) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Presence',
          trailing: MonoValue(
            (value * 100).round(),
            suffix: '%',
            style: TraceText.monoSmall,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: TraceSpace.md),
        ProgressTrack(value: value),
      ],
    );
  }

  Widget _oneLine(BuildContext context, Note? note) {
    final c = context.traceColors;
    final hasNote = note != null && note.body.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('One line'),
        const SizedBox(height: TraceSpace.md),
        PressScale(
          onTap: () => OneLineSheet.show(context, initial: note?.body),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasNote ? note.body : 'One line about today.',
                  style: TraceText.body.copyWith(
                    color: hasNote ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: c.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}
