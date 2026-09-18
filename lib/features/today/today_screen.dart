import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../core/parser/quantity_grammar.dart';
import '../../shared/widgets/day_picker.dart';
import '../../shared/widgets/entry_row.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import '../../shared/widgets/undo_bar.dart';
import '../entries/add_entry_screen.dart';
import '../entries/entry_draft.dart';
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
    final today = DateTime.parse(ref.watch(currentDayProvider));
    final day = DateTime.parse(ref.watch(selectedDateProvider));
    final entriesAsync = ref.watch(todayEntriesProvider);
    final oneLine = ref.watch(oneLineProvider).value;
    final presence = ref.watch(presenceProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        // Held back a beat at launch so the cascade plays under the app
        // settling into view rather than being hidden by it.
        child: RevealScope(
          delay: const Duration(milliseconds: 180),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              TraceSpace.lg,
              context.gutter,
              TraceSpace.xxxl,
            ),
            children: [
              _header(context, ref, day, today).reveal(0),
              const SizedBox(height: TraceSpace.xxl),
              _greetingBlock(context, now),
              const SizedBox(height: TraceSpace.section),
              // Names the day on screen, so a day browsed back to is never
              // mistaken for today.
              SectionLabel(dayLabel(day, today)).reveal(3),
              const SizedBox(height: TraceSpace.xs),
              // One child, however many entries: the fixed sections below keep
              // their slots when an entry is added, so they are never remounted
              // and never replay their own animations.
              entriesAsync.when(
                data: (entries) => entries.isEmpty
                    ? _emptyState(context)
                    : _entryList(context, ref, entries),
                // The list is local SQLite: it resolves within a frame. A
                // spinner here would flash rather than inform.
                loading: () => const SizedBox(height: TraceSpace.xxxl),
                error: (e, _) => _errorState(context, e),
              ),
              const SizedBox(height: TraceSpace.lg),
              TraceButton(
                '+ Add entry',
                icon: null,
                onPressed: onAddEntry,
              ).reveal(_afterRows),
              const SizedBox(height: TraceSpace.section),
              _presence(context, presence).reveal(_afterRows + 1),
              const SizedBox(height: TraceSpace.section),
              _oneLine(context, oneLine).reveal(_afterRows + 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Cascade slot for the sections under the entry list. Fixed rather than
  /// counted from the entries, which usually arrive a frame after the first
  /// build — a counted slot would let the button beat the rows above it.
  static const _afterRows = 8;

  /// When the presence bar starts filling: once its section has faded in.
  static const _presenceFill = Duration(milliseconds: 180 + 55 * 9 + 160);

  /// The date doubles as the way to another day: tap it to look back at, or
  /// fill in, a day already gone.
  Widget _header(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    DateTime today,
  ) {
    final c = context.traceColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('TRACE',
            style: TraceText.wordmarkSmall.copyWith(color: c.textPrimary)),
        PressScale(
          onTap: () async {
            final picked =
                await showDayPicker(context, selected: day, today: today);
            if (picked != null) {
              ref.read(selectedDateProvider.notifier).select(dayKey(picked));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TraceSpace.xs),
            child: Row(
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(day),
                  style:
                      TraceText.rowSubtitle.copyWith(color: c.textSecondary),
                ),
                const SizedBox(width: TraceSpace.sm),
                Icon(Icons.calendar_today_outlined,
                    size: 15, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Two lines, two beats: the greeting, then the name, each resolving out of
  /// a slight blur — the one place on the screen that is about the person
  /// rather than the record.
  Widget _greetingBlock(BuildContext context, DateTime now) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(now.hour),
          style: TraceText.greetingLine.copyWith(color: c.textSecondary),
        ).reveal(1, focus: true),
        const SizedBox(height: 2),
        Text(
          'Leigh.',
          style: TraceText.greetingName.copyWith(color: c.textPrimary),
        ).reveal(2, focus: true),
      ],
    );
  }

  Widget _entryList(BuildContext context, WidgetRef ref, List<Entry> entries) {
    final c = context.traceColors;
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          // Keyed by entry, so a new entry is the only new element: it opens
          // a space in the list and fades into it, while the rows already
          // there simply move.
          Column(
            children: [
              if (i > 0) Divider(color: c.border, height: 1),
              Dismissible(
                key: ValueKey(entries[i].id),
                direction: DismissDirection.endToStart,
                background: _deleteBackground(context),
                onDismissed: (_) {
                  final repo = ref.read(entryRepositoryProvider);
                  final id = entries[i].id;
                  repo.delete(id);
                  showUndo(
                    context,
                    message: 'Entry deleted',
                    onUndo: () => repo.restore(id),
                  );
                },
                child: EntryRow(
                  category: entries[i].categoryEnum,
                  title: entries[i].title,
                  duration: entries[i].durationOrNull,
                  quantityLabel: _quantityLabel(entries[i]),
                  // Flies into the category tile on the edit screen. Only
                  // Today sets this: Timeline shares the same shell route, and
                  // a second row with the same tag would be a duplicate Hero.
                  heroTag: 'entry-glyph-${entries[i].id}',
                  onTap: () => _edit(context, entries[i]),
                  // Ticks up as its row lands, not before it is visible.
                  valueDelay: Duration(milliseconds: 180 + 55 * (4 + i)),
                ),
              ),
            ],
          ).reveal(
            4 + i.clamp(0, 6),
            late: RevealLate.expand,
            key: ValueKey('row-${entries[i].id}'),
          ),
      ],
    );
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
      child:
          Icon(Icons.delete_outline_rounded, size: 20, color: c.textSecondary),
    );
  }

  void _edit(BuildContext context, Entry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEntryScreen(
          entryId: entry.id,
          draft: EntryDraft.fromEntry(entry),
        ),
      ),
    );
  }

  /// Absence, not failure. No prompt, no nudge, no empty-state illustration.
  Widget _emptyState(BuildContext context) {
    final c = context.traceColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TraceSpace.xl),
        child: Text(
          'Nothing recorded yet.',
          style: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ),
    ).reveal(4);
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
          // Counts in step with the bar, so the number and the fill read as
          // one measurement.
          trailing: MonoValue(
            (value * 100).round(),
            suffix: '%',
            style: TraceText.monoSmall,
            color: c.textPrimary,
            delay: _presenceFill,
          ),
        ),
        const SizedBox(height: TraceSpace.md),
        ProgressTrack(value: value, delay: _presenceFill),
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
                // A new line settles in over the old one rather than cutting.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: TraceMotion.emphasizedDecelerate,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: TraceButton.labelTransition,
                  child: Text(
                    hasNote ? note.body : 'One line about today.',
                    key: ValueKey(hasNote ? note.body : null),
                    style: TraceText.body.copyWith(
                      color: hasNote ? c.textPrimary : c.textSecondary,
                    ),
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
