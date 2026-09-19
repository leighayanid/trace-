import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database_provider.dart';
import '../../shared/widgets/category_glyph.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/day_picker.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import '../../shared/widgets/undo_bar.dart';
import '../entries/entry_providers.dart';
import '../entries/entry_repository.dart';
import 'commit_days.dart';
import 'git_providers.dart';
import 'github_client.dart';

/// Turns the last two weeks of commits into BUILD entries — ones you pick.
///
/// Nothing is added until you say so. Each repository-day is one suggestion,
/// ticked unless something is already recorded for it.
class ImportCommitsScreen extends ConsumerWidget {
  const ImportCommitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final account = ref.watch(gitHubAccountProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: account.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const _Connect(),
          data: (a) => a == null ? const _Connect() : _Suggestions(account: a),
        ),
      ),
    );
  }
}

Widget _back(BuildContext context) {
  final c = context.traceColors;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
    child: Align(
      alignment: Alignment.centerLeft,
      child: PressScale(
        onTap: () => Navigator.of(context).pop(),
        child: Icon(Icons.chevron_left_rounded, size: 26, color: c.textPrimary),
      ),
    ),
  );
}

// ── Not connected ─────────────────────────────────────────────────────────

class _Connect extends ConsumerStatefulWidget {
  const _Connect();

  @override
  ConsumerState<_Connect> createState() => _ConnectState();
}

class _ConnectState extends ConsumerState<_Connect> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_token.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(gitHubAccountProvider.notifier).connect(_token.text);
    } on GitHubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final explain = TraceText.rowSubtitle.copyWith(
      color: c.textSecondary,
      height: 1.5,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        0,
        context.gutter,
        TraceSpace.xxxl,
      ),
      children: [
        _back(context),
        Text(
          'Import commits',
          style: TraceText.screenTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: TraceSpace.md),
        Text(
          'TRACE can read your own GitHub commits and suggest BUILD entries '
          'from them — one per repository per day, for you to pick from. '
          'Nothing is added without you.',
          style: TraceText.body.copyWith(color: c.textSecondary, height: 1.6),
        ),
        const SizedBox(height: TraceSpace.section),
        const SectionLabel('Token'),
        const SizedBox(height: TraceSpace.md),
        Text(
          'Create a fine-grained token at github.com → Settings → Developer '
          'settings → Personal access tokens. Give it the repositories you '
          'want, and one permission: Contents, read-only.',
          style: explain,
        ),
        const SizedBox(height: TraceSpace.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: TraceSpace.md),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(TraceRadius.card),
          ),
          child: TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: TraceText.mono.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'github_pat_…',
              hintStyle: TraceText.mono.copyWith(color: c.textSecondary),
            ),
            onSubmitted: (_) => _connect(),
          ),
        ),
        const SizedBox(height: TraceSpace.md),
        TraceButton(
          _busy ? 'Checking…' : 'Connect',
          onPressed: _busy ? null : _connect,
        ),
        if (_error != null) ...[
          const SizedBox(height: TraceSpace.md),
          Text(
            _error!,
            style: TraceText.rowSubtitle.copyWith(color: c.textPrimary),
          ),
        ],
        const SizedBox(height: TraceSpace.xl),
        Text(
          'The token stays in this device\'s secure storage. It is never '
          'synced, and TRACE only uses it when you open this screen. Commits '
          'are read from each repository\'s default branch.',
          style: explain,
        ),
      ],
    );
  }
}

// ── Connected ─────────────────────────────────────────────────────────────

class _Suggestions extends ConsumerStatefulWidget {
  const _Suggestions({required this.account});

  final ({String token, String login}) account;

  @override
  ConsumerState<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends ConsumerState<_Suggestions> {
  /// Two weeks: long enough to catch up after a busy stretch, short enough
  /// that the list stays something you can read.
  static const _days = 14;

  late Future<List<CommitDay>> _load = _fetch();
  Set<int>? _picked;
  bool _adding = false;

  DateTime get _today => DateTime.parse(ref.read(currentDayProvider));

  Future<List<CommitDay>> _fetch() async {
    final today = _today;
    final since = DateTime(today.year, today.month, today.day - (_days - 1));
    final client = GitHubClient(token: widget.account.token);
    try {
      final commits = await client.commitsSince(widget.account.login, since);
      final db = ref.read(databaseProvider);
      return groupCommits(
        commits,
        projects: await db.allProjects(),
        existing: await db
            .watchEntriesBetween(dayKey(since), dayKey(today))
            .first,
      );
    } finally {
      client.close();
    }
  }

  Future<void> _add(List<CommitDay> days, Set<int> picked) async {
    if (picked.isEmpty || _adding) return;
    setState(() => _adding = true);
    final repo = ref.read(entryRepositoryProvider);
    final ids = [
      for (final i in picked.toList()..sort())
        await repo.create(days[i].toDraft()),
    ];
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showUndo(
      context,
      message: ids.length == 1
          ? 'Added 1 entry'
          : 'Added ${ids.length} entries',
      onUndo: () async {
        for (final id in ids) {
          await repo.delete(id);
        }
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return FutureBuilder<List<CommitDay>>(
      future: _load,
      builder: (context, snap) {
        final days = snap.data;
        final picked = _picked ??= days == null
            ? null
            : {
                for (final (i, d) in days.indexed)
                  if (!d.logged) i,
              };

        return ListView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            TraceSpace.xxxl,
          ),
          children: [
            _back(context),
            Text(
              'Import commits',
              style: TraceText.screenTitle.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: TraceSpace.xs),
            Text(
              '@${widget.account.login} · last $_days days',
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: TraceSpace.xl),
            if (snap.connectionState != ConnectionState.done)
              Text(
                'Reading commits…',
                style: TraceText.body.copyWith(color: c.textSecondary),
              )
            else if (snap.hasError)
              _failed(context, snap.error!)
            else if (days!.isEmpty)
              Text(
                'No commits in the last $_days days.',
                style: TraceText.body.copyWith(color: c.textSecondary),
              )
            else ...[
              ..._list(context, days, picked!),
              const SizedBox(height: TraceSpace.xl),
              TraceButton(
                _adding
                    ? 'Adding…'
                    : picked.isEmpty
                    ? 'Nothing picked'
                    : picked.length == 1
                    ? 'Add 1 entry'
                    : 'Add ${picked.length} entries',
                onPressed: picked.isEmpty || _adding
                    ? null
                    : () => _add(days, picked),
              ),
            ],
            const SizedBox(height: TraceSpace.section),
            Center(
              child: TraceButton.text(
                'Disconnect GitHub',
                onPressed: () =>
                    ref.read(gitHubAccountProvider.notifier).disconnect(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _failed(BuildContext context, Object error) {
    final c = context.traceColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error is GitHubException ? error.message : "Couldn't read commits.",
          style: TraceText.body.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: TraceSpace.md),
        TraceButton.outlined(
          'Try again',
          onPressed: () => setState(() {
            _picked = null;
            _load = _fetch();
          }),
        ),
      ],
    );
  }

  /// Grouped by day, newest first, the way the Timeline reads.
  List<Widget> _list(
    BuildContext context,
    List<CommitDay> days,
    Set<int> picked,
  ) {
    final c = context.traceColors;
    final today = _today;
    final out = <Widget>[];
    DateTime? current;
    for (final (i, d) in days.indexed) {
      if (d.date != current) {
        current = d.date;
        if (out.isNotEmpty) out.add(const SizedBox(height: TraceSpace.lg));
        out
          ..add(SectionLabel(dayLabel(d.date, today)))
          ..add(const SizedBox(height: TraceSpace.xs));
      }
      final on = picked.contains(i);
      out.add(
        PressScale(
          onTap: () => setState(() => on ? picked.remove(i) : picked.add(i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CategoryGlyph(category: Category.build, size: 28),
                const SizedBox(width: TraceSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        style: TraceText.body.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          d.messages.length == 1
                              ? '1 commit'
                              : '${d.messages.length} commits',
                          if (d.logged) 'already recorded',
                          d.messages.first,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TraceText.rowSubtitle.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TraceSpace.md),
                Icon(
                  on ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: on ? c.navy : c.border,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }
}
