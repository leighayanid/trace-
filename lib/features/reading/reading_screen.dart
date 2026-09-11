import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../entries/entry_providers.dart';
import 'book_detail_screen.dart';
import 'book_repository.dart';
import 'new_book_sheet.dart';

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
              child: books.when(
                data: (list) =>
                    list.isEmpty ? _empty(context) : _list(context, list),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => _error(context),
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

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        TraceSpace.xl,
        context.gutter,
        TraceSpace.xxxl,
      ),
      children: [
        for (var i = 0; i < reading.length; i++)
          _BookRow(book: reading[i], index: i),
        if (others.isNotEmpty) ...[
          const SizedBox(height: TraceSpace.section),
          for (var i = 0; i < others.length; i++)
            _BookRow(book: others[i], index: i, dimmed: true),
        ],
      ],
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
      ),
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

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.index,
    this.dimmed = false,
  });

  final Book book;
  final int index;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final total = book.totalPages;
    final progress = total == null || total == 0
        ? null
        : (book.currentPage / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.xl),
      child: PressScale(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookDetailScreen(bookId: book.id),
          ),
        ),
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title,
                  style: TraceText.bookTitle.copyWith(color: c.textPrimary)),
              if (book.author != null && book.author!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(book.author!,
                    style: TraceText.rowSubtitle
                        .copyWith(color: c.textSecondary)),
              ],
              const SizedBox(height: TraceSpace.md),
              if (progress != null) ...[
                Row(
                  children: [
                    Expanded(child: ProgressTrack(value: progress)),
                    const SizedBox(width: TraceSpace.md),
                    Text('${(progress * 100).round()}%',
                        style: TraceText.monoSmall
                            .copyWith(color: c.textPrimary)),
                  ],
                ),
                const SizedBox(height: TraceSpace.sm),
                Text('${book.currentPage} / $total pages',
                    style: TraceText.mono.copyWith(color: c.textSecondary)),
              ] else
                Text('${book.currentPage} pages read',
                    style: TraceText.mono.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
          delay: TraceMotion.rowStagger * index,
          duration: TraceMotion.base,
        );
  }
}
