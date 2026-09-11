import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import '../notes/note_providers.dart';
import 'log_reading_sheet.dart';
import 'reading_providers.dart';

/// One book, read editorially: cover, progress, the last thought it left.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final book = ref.watch(bookByIdProvider(bookId)).value;
    final sessions =
        ref.watch(bookSessionsProvider(bookId)).value ?? const <Entry>[];
    final notes = ref.watch(bookNotesProvider(bookId)).value ?? const <Note>[];

    if (book == null) {
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.shrink());
    }

    final total = book.totalPages;
    final progress = total == null || total == 0
        ? null
        : (book.currentPage / total).clamp(0.0, 1.0);
    final lastSession = sessions.firstOrNull;
    final lastThought = notes.firstOrNull;

    final todayPages = sessions
        .where((e) => e.date == DateFormat('yyyy-MM-dd').format(DateTime.now()))
        .fold<double>(0, (sum, e) => sum + (e.quantity ?? 0));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            TraceSpace.xxxl,
          ),
          children: [
            _topBar(context),
            const SectionLabel('Reading'),
            const SizedBox(height: TraceSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cover(context, book),
                const SizedBox(width: TraceSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title,
                          style: TraceText.bookTitle
                              .copyWith(color: c.textPrimary)),
                      if (book.author != null && book.author!.isNotEmpty) ...[
                        const SizedBox(height: TraceSpace.xs),
                        Text(book.author!,
                            style: TraceText.rowSubtitle
                                .copyWith(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TraceSpace.xl),
            if (progress != null) ...[
              Row(
                children: [
                  Expanded(child: ProgressTrack(value: progress)),
                  const SizedBox(width: TraceSpace.md),
                  Text('${(progress * 100).round()}%',
                      style:
                          TraceText.monoSmall.copyWith(color: c.textPrimary)),
                ],
              ),
              const SizedBox(height: TraceSpace.md),
              Text('${book.currentPage} / $total pages',
                  style: TraceText.mono.copyWith(color: c.textSecondary)),
            ] else
              Text('${book.currentPage} pages read',
                  style: TraceText.mono.copyWith(color: c.textSecondary)),
            if (lastSession != null) ...[
              const SizedBox(height: TraceSpace.section),
              const SectionLabel('Last read'),
              const SizedBox(height: TraceSpace.sm),
              Text(
                _relativeDate(lastSession.date),
                style: TraceText.rowSubtitle.copyWith(color: c.textPrimary),
              ),
            ],
            if (lastThought != null) ...[
              const SizedBox(height: TraceSpace.section),
              const SectionLabel('Current thought'),
              const SizedBox(height: TraceSpace.md),
              Container(
                padding: const EdgeInsets.only(left: TraceSpace.lg),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.border, width: 2)),
                ),
                child: Text(
                  '"${lastThought.body}"',
                  style: TraceText.quote.copyWith(color: c.textPrimary),
                ),
              ),
            ],
            if (todayPages > 0) ...[
              const SizedBox(height: TraceSpace.section),
              const SectionLabel('Today'),
              const SizedBox(height: TraceSpace.sm),
              Text('${todayPages.round()} pages',
                  style: TraceText.mono.copyWith(color: c.textPrimary)),
            ],
            const SizedBox(height: TraceSpace.section),
            TraceButton('Log reading',
                onPressed: () => LogReadingSheet.show(context, book)),
            const SizedBox(height: TraceSpace.md),
            TraceButton.outlined(
              notes.isEmpty ? 'No notes yet' : 'View ${notes.length} notes',
              onPressed: notes.isEmpty ? null : () {},
            ),
          ],
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
