import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/undo_bar.dart';
import '../entries/add_entry_screen.dart';
import '../entries/entry_draft.dart';
import '../entries/entry_providers.dart';
import 'project_providers.dart';

/// Every session logged against a project, newest first.
///
/// The detail screen shows the last five; this is the rest of the record. Each
/// row opens for editing and swipes away, the same as on Today.
class ProjectSessionsScreen extends ConsumerWidget {
  const ProjectSessionsScreen({
    super.key,
    required this.projectId,
    required this.name,
  });

  final String projectId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final sessions =
        ref.watch(projectSessionsProvider(projectId)).value ?? const <Entry>[];

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
            Text(name,
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.xs),
            Text(
              '${sessions.length} '
              '${sessions.length == 1 ? 'session' : 'sessions'}',
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: TraceSpace.xl),
            for (final (i, e) in sessions.indexed) ...[
              if (i > 0) Divider(color: c.border, height: 1),
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: TraceSpace.md),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: c.textSecondary),
                ),
                onDismissed: (_) {
                  final repo = ref.read(entryRepositoryProvider);
                  repo.delete(e.id);
                  showUndo(
                    context,
                    message: 'Session deleted',
                    onUndo: () => repo.restore(e.id),
                  );
                },
                child: SessionRow(
                  entry: e,
                  showNote: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddEntryScreen(
                        entryId: e.id,
                        draft: EntryDraft.fromEntry(e),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One session: its day, its time, and — where there is room — its note.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.entry,
    this.showNote = false,
    this.onTap,
  });

  final Entry entry;
  final bool showNote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final note = entry.description;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, yyyy')
                        .format(DateTime.parse(entry.date)),
                    style:
                        TraceText.rowSubtitle.copyWith(color: c.textSecondary),
                  ),
                  if (showNote && note != null && note.isNotEmpty) ...[
                    const SizedBox(height: TraceSpace.xs),
                    Text(
                      note,
                      style: TraceText.body.copyWith(color: c.textPrimary),
                    ),
                  ],
                ],
              ),
            ),
            if (entry.durationSecs != null)
              MonoDuration(
                Duration(seconds: entry.durationSecs!),
                format: DurationFormat.human,
                animate: false,
              ),
          ],
        ),
      ),
    );
  }
}
