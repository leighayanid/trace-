import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/undo_bar.dart';
import '../notes/note_providers.dart';

/// Every quote and thought kept from a book, newest first.
///
/// Read like a margin, not a list. A quote is the author's words, so it is set
/// in the quote face inside quotation marks, with its page; a thought is the
/// reader's own, set plainly. A note swipes away, with a moment to take it
/// back.
class BookNotesScreen extends ConsumerWidget {
  const BookNotesScreen({
    super.key,
    required this.bookId,
    required this.title,
  });

  final String bookId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final notes = ref.watch(bookNotesProvider(bookId)).value ?? const <Note>[];

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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PressScale(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 26, color: c.textPrimary),
                ),
              ),
            ),
            Text(title,
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.xs),
            Text(
              '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: TraceSpace.xl),
            for (final n in notes)
              Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: TraceSpace.md),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: c.textSecondary),
                ),
                onDismissed: (_) {
                  final repo = ref.read(noteRepositoryProvider);
                  repo.setDeleted(n.id, deleted: true);
                  showUndo(
                    context,
                    message: 'Note deleted',
                    onUndo: () => repo.setDeleted(n.id, deleted: false),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: TraceSpace.xl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: TraceSpace.lg),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: c.border, width: 2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.kind == 'quote' ? '"${n.body}"' : n.body,
                          style: (n.kind == 'quote'
                                  ? TraceText.quote
                                  : TraceText.body)
                              .copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: TraceSpace.sm),
                        Text(
                          [
                            if (n.kind == 'quote' && n.page != null)
                              'p. ${n.page}',
                            DateFormat('MMM d, yyyy')
                                .format(n.createdAt.toLocal()),
                          ].join(' · '),
                          style: TraceText.rowSubtitle
                              .copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
