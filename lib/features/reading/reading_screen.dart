import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/hero_text.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/reveal.dart';
import '../entries/entry_providers.dart';
import 'book_detail_screen.dart';
import 'book_repository.dart';
import 'new_book_sheet.dart';
import 'reading_providers.dart';

/// Reading deserves its own surface — editorial, not a task list.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final books = ref.watch(booksProvider);

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
                  Text('Reading',
                      style:
                          TraceText.screenTitle.copyWith(color: c.textPrimary)),
                  PressScale(
                    onTap: () => NewBookSheet.show(context),
                    scale: 0.9,
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.xs),
                      child: Icon(Icons.add_rounded,
                          size: 22, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RevealScope(
                delay: const Duration(milliseconds: 140),
                child: books.when(
                  data: (list) =>
                      list.isEmpty ? _empty(context) : _list(context, list),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => _error(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Book> books) {
    final reading =
        books.where((b) => b.status == BookStatus.reading.key).toList();
    final others =
        books.where((b) => b.status != BookStatus.reading.key).toList();

    // Eager rather than lazy, as on Projects: a lazy list rebuilds rows as they
    // scroll back in, which would replay a new book's arrival on old ones.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        TraceSpace.xl,
        context.gutter,
        TraceSpace.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < reading.length; i++)
            _BookRow(book: reading[i], index: i).reveal(
              i.clamp(0, 7),
              late: RevealLate.expand,
              key: ValueKey(reading[i].id),
            ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: TraceSpace.section),
            for (var i = 0; i < others.length; i++)
              _BookRow(
                book: others[i],
                index: reading.length + i,
                dimmed: true,
              ).reveal(
                (reading.length + i).clamp(0, 7),
                late: RevealLate.expand,
                key: ValueKey(others[i].id),
              ),
          ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.traceColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TraceSpace.xxl),
        child: Text(
          'No books yet.',
          style: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ).reveal(0),
    );
  }

  Widget _error(BuildContext context) {
    final c = context.traceColors;
    return Center(
      child: Text("Couldn't read your books.",
          style: TraceText.body.copyWith(color: c.textSecondary)),
    );
  }
}

class _BookRow extends ConsumerWidget {
  const _BookRow({
    required this.book,
    required this.index,
    this.dimmed = false,
  });

  final Book book;
  final int index;
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final pagesRead = ref.watch(pagesReadProvider).value?[book.id] ?? 0;
    final total = book.totalPages;
    final page = book.currentPage(pagesRead);
    final progress = book.progress(pagesRead);
    // The bar fills once the row has landed.
    final fill = Duration(milliseconds: 140 + 55 * index.clamp(0, 7) + 220);

    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.xl),
      child: PressScale(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailScreen(bookId: book.id, initial: book),
          ),
        ),
        // Animated, so a book moving between Reading and Finished settles into
        // its new weight rather than snapping.
        child: AnimatedOpacity(
          opacity: dimmed ? 0.55 : 1,
          duration: TraceMotion.base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroText(
                book.title,
                tag: BookDetailScreen.titleTag(book.id),
                style: TraceText.bookTitle.copyWith(color: c.textPrimary),
              ),
              if (book.author != null && book.author!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(book.author!,
                    style:
                        TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: TraceSpace.md),
              if (progress != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: ProgressTrack(value: progress, delay: fill),
                    ),
                    const SizedBox(width: TraceSpace.md),
                    MonoValue(
                      (progress * 100).round(),
                      suffix: '%',
                      style: TraceText.monoSmall,
                      color: c.textPrimary,
                      delay: fill,
                    ),
                  ],
                ),
                const SizedBox(height: TraceSpace.sm),
                Text('$page / $total pages',
                    style: TraceText.mono.copyWith(color: c.textSecondary)),
              ] else
                Text('$page pages read',
                    style: TraceText.mono.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
