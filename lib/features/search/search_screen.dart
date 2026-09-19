import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/entry_row.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../entries/add_entry_screen.dart';
import '../entries/entry_draft.dart';
import '../entries/entry_repository.dart';
import 'search_providers.dart';

/// "When did I first start learning about Durable Objects?"
///
/// One field over everything recorded — entry titles and notes, the projects
/// and books they belong to, one-lines and reading thoughts. The answer leads
/// with when: the first day, the latest, and how many times in between.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Settles for a beat before searching, so each keystroke does not start a
  /// query the next one replaces.
  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter - TraceSpace.sm,
                TraceSpace.sm,
                context.gutter,
                TraceSpace.md,
              ),
              child: Row(
                children: [
                  PressScale(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(TraceSpace.sm),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 26,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: TraceSpace.xs),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _changed,
                      textInputAction: TextInputAction.search,
                      style: TraceText.body.copyWith(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search your record',
                        hintStyle: TraceText.body.copyWith(
                          color: c.textSecondary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.border, height: 1),
            Expanded(
              child: _query.isEmpty ? _hint(context) : _Results(query: _query),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context) {
    final c = context.traceColors;
    return Padding(
      padding: EdgeInsets.all(context.gutter),
      child: Text(
        'Titles, notes, projects, books and one-lines — every word you type '
        'has to appear.',
        style: TraceText.rowSubtitle.copyWith(
          color: c.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  static final _long = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final entries = ref.watch(searchEntriesProvider(query)).value;
    final notes = ref.watch(searchNotesProvider(query)).value;
    final span = ref.watch(searchSpanProvider(query)).value;

    // Local SQLite answers within a frame; a spinner would only flash.
    if (entries == null || notes == null) return const SizedBox.shrink();

    if (entries.isEmpty && notes.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.gutter),
        child: Text(
          'Nothing matches "$query".',
          style: TraceText.body.copyWith(color: c.textSecondary),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        TraceSpace.lg,
        context.gutter,
        TraceSpace.xxxl,
      ),
      children: [
        if (span != null && span.count > 0) ...[
          _answer(context, span),
          const SizedBox(height: TraceSpace.xl),
        ],
        if (entries.isNotEmpty) ...[
          SectionLabel(
            'Entries',
            trailing: Text(
              entries.length < (span?.count ?? 0)
                  ? 'latest $searchLimit of ${span!.count}'
                  : '${entries.length}',
              style: TraceText.monoSmall.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: TraceSpace.sm),
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) Divider(color: c.border, height: 1),
            Padding(
              padding: const EdgeInsets.only(top: TraceSpace.md),
              child: Text(
                _long.format(DateTime.parse(e.date)),
                style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
              ),
            ),
            EntryRow(
              category: e.categoryEnum,
              title: e.title,
              duration: e.durationOrNull,
              quantityLabel: e.quantityLabel,
              animateValue: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEntryScreen(
                    entryId: e.id,
                    draft: EntryDraft.fromEntry(e),
                  ),
                ),
              ),
            ),
          ],
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: TraceSpace.section),
          SectionLabel(
            'Notes',
            trailing: Text(
              '${notes.length}',
              style: TraceText.monoSmall.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: TraceSpace.md),
          for (final n in notes) _note(context, n),
        ],
      ],
    );
  }

  /// The answer to "when": first, latest, how many.
  Widget _answer(
    BuildContext context,
    ({String? first, String? last, int count}) span,
  ) {
    final c = context.traceColors;
    final first = _long.format(DateTime.parse(span.first!));
    final last = _long.format(DateTime.parse(span.last!));
    return Text(
      span.count == 1
          ? 'Once, on $first.'
          : 'First on $first, most recently $last — ${span.count} entries.',
      style: TraceText.body.copyWith(color: c.textPrimary, height: 1.5),
    );
  }

  Widget _note(BuildContext context, Note n) {
    final c = context.traceColors;
    final kind = switch (n.kind) {
      'one_line' => 'One line',
      'quote' => 'Quote',
      'thought' => 'Thought',
      _ => 'Note',
    };
    final day = n.date != null
        ? DateTime.parse(n.date!)
        : n.createdAt.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: TraceSpace.lg),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.border, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.body, style: TraceText.body.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.xs),
            Text(
              '$kind · ${_long.format(day)}',
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
