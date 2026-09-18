import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/hero_text.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import '../notes/note_providers.dart';
import 'log_reading_sheet.dart';
import 'book_repository.dart';
import 'reading_providers.dart';

/// One book, read editorially: cover, progress, the last thought it left.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId, this.initial});

  final String bookId;

  /// The book as the list already has it, shown until the live row arrives —
  /// the title's Hero needs its destination on the very first frame.
  final Book? initial;

  /// Shared with the book's row on Reading, so the title carries across.
  static Object titleTag(String bookId) => 'book-title-$bookId';

  /// The page's cascade trails its arrival so the title lands first.
  static const _follow = Duration(milliseconds: 140);

  /// When the bar starts filling: after its row has faded in.
  static const _fill = Duration(milliseconds: 140 + 55 * 2 + 200);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final book = ref.watch(bookByIdProvider(bookId)).value ?? initial;
    final sessions =
        ref.watch(bookSessionsProvider(bookId)).value ?? const <Entry>[];
    final notes = ref.watch(bookNotesProvider(bookId)).value ?? const <Note>[];

    if (book == null) {
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.shrink());
    }

    final pagesRead = ref.watch(pagesReadProvider).value?[bookId] ?? 0;
    final total = book.totalPages;
    final page = book.currentPage(pagesRead);
    final progress = book.progress(pagesRead);
    final lastSession = sessions.firstOrNull;
    final lastThought = notes.firstOrNull;

    final todayPages = sessions
        .where((e) => e.date == DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .fold<double>(0, (sum, e) => sum + (e.quantity ?? 0));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RevealScope(
          delay: _follow,
          // A Column rather than a lazy ListView, and every section keyed: the
          // sections below appear as data arrives (a first session, a first
          // thought), and neither laziness nor position may make an existing
          // section remount — its bar would refill from zero.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              0,
              context.gutter,
              TraceSpace.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context),
                const SectionLabel('Reading').reveal(0),
                const SizedBox(height: TraceSpace.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cover(context, book).reveal(1, focus: true),
                    const SizedBox(width: TraceSpace.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Not revealed: this is the title that flew in.
                          HeroText(
                            book.title,
                            tag: titleTag(book.id),
                            style: TraceText.bookTitle.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          if (book.author != null &&
                              book.author!.isNotEmpty) ...[
                            const SizedBox(height: TraceSpace.xs),
                            Text(
                              book.author!,
                              style: TraceText.rowSubtitle.copyWith(
                                color: c.textSecondary,
                              ),
                            ).reveal(1),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TraceSpace.xl),
                // Progress, last read, the thought, today: one editorial column,
                // each section a beat after the one above.
                if (progress != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Moves from the old value when a session is logged,
                          // so the pages just read are visible as distance
                          // travelled.
                          Expanded(
                            child: ProgressTrack(value: progress, delay: _fill),
                          ),
                          const SizedBox(width: TraceSpace.md),
                          MonoValue(
                            (progress * 100).round(),
                            suffix: '%',
                            style: TraceText.monoSmall,
                            color: c.textPrimary,
                            delay: _fill,
                          ),
                        ],
                      ),
                      const SizedBox(height: TraceSpace.md),
                      Text(
                        '$page / $total pages',
                        style: TraceText.mono.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ).reveal(2, key: const ValueKey('progress'))
                else
                  Text(
                    '$page pages read',
                    style: TraceText.mono.copyWith(color: c.textSecondary),
                  ).reveal(2, key: const ValueKey('pages')),
                // Each optional section carries its own leading space, so it
                // arrives and leaves as one piece.
                if (lastSession != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: TraceSpace.section),
                      const SectionLabel('Last read'),
                      const SizedBox(height: TraceSpace.sm),
                      Text(
                        _relativeDate(lastSession.date),
                        style: TraceText.rowSubtitle.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ).reveal(
                    4,
                    late: RevealLate.expand,
                    key: const ValueKey('last-read'),
                  ),
                if (lastThought != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: TraceSpace.section),
                      const SectionLabel('Current thought'),
                      const SizedBox(height: TraceSpace.md),
                      // A new thought settles in over the last one.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: TraceMotion.emphasizedDecelerate,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topLeft,
                          children: [...previous, ?current],
                        ),
                        transitionBuilder: TraceButton.labelTransition,
                        child: Container(
                          key: ValueKey(lastThought.id),
                          padding: const EdgeInsets.only(left: TraceSpace.lg),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: c.border, width: 2),
                            ),
                          ),
                          child: Text(
                            '"${lastThought.body}"',
                            style: TraceText.quote.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).reveal(
                    5,
                    focus: true,
                    late: RevealLate.expand,
                    key: const ValueKey('thought'),
                  ),
                if (todayPages > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: TraceSpace.section),
                      const SectionLabel('Today'),
                      const SizedBox(height: TraceSpace.sm),
                      MonoValue(
                        todayPages.round(),
                        suffix: ' pages',
                        color: c.textPrimary,
                        delay: _follow + TraceMotion.cascade * 6,
                      ),
                    ],
                  ).reveal(
                    6,
                    late: RevealLate.expand,
                    key: const ValueKey('today'),
                  ),
                const SizedBox(height: TraceSpace.section),
                TraceButton(
                  'Log reading',
                  onPressed: () => LogReadingSheet.show(context, book),
                ).reveal(7, key: const ValueKey('log')),
                const SizedBox(height: TraceSpace.md),
                TraceButton.outlined(
                  notes.isEmpty ? 'No notes yet' : 'View ${notes.length} notes',
                  onPressed: notes.isEmpty ? null : () {},
                ).reveal(8, key: const ValueKey('notes')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final c = context.traceColors;
    return Padding(
      padding: const EdgeInsets.only(
        bottom: TraceSpace.lg,
        top: TraceSpace.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.chevron_left_rounded,
                size: 26, color: c.textPrimary),
          ),
          Icon(Icons.more_horiz_rounded, size: 20, color: c.textSecondary),
        ],
      ),
    );
  }

  /// A typographic stand-in for a cover image.
  ///
  /// Covers need fetching or a file picker; neither is built. An initial on navy
  /// keeps the layout honest rather than showing a broken image frame.
  Widget _cover(BuildContext context, Book book) {
    final c = context.traceColors;
    return Container(
      width: 62,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.navyLight,
        borderRadius: BorderRadius.circular(TraceRadius.glyph),
      ),
      child: Text(
        book.title.trim().isEmpty ? '?' : book.title.trim()[0].toUpperCase(),
        style: TraceText.bookTitle.copyWith(color: c.navy, fontSize: 24),
      ),
    );
  }

  static String _relativeDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final today = DateTime.now();
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
