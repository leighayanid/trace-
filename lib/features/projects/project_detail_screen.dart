import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/category_glyph.dart';
import '../../shared/widgets/hero_text.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import 'project_providers.dart';
import 'project_sessions_screen.dart';
import 'project_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId, this.initial});

  final String projectId;

  /// The project as the list already has it, shown until the live row
  /// arrives. The name's Hero needs its destination on the very first frame;
  /// without this the page is blank for that frame and the flight never
  /// starts.
  final Project? initial;

  /// Shared with the project's card, so the name carries across the push.
  static Object titleTag(String projectId) => 'project-name-$projectId';

  /// The page's own cascade trails its arrival slightly, so the title lands
  /// first and everything under it follows.
  static const _follow = Duration(milliseconds: 140);

  /// When the bar starts filling: after its row has faded in.
  static const _fill = Duration(milliseconds: 140 + 55 * 3 + 200);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final project = ref.watch(projectByIdProvider(projectId)).value ?? initial;
    final time =
        ref.watch(projectTimeProvider(projectId)).value ?? Duration.zero;
    final sessions =
        ref.watch(projectSessionsProvider(projectId)).value ?? const <Entry>[];

    if (project == null) {
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.shrink());
    }

    final status = ProjectStatus.parse(project.status);
    final target = project.targetSecs;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RevealScope(
          delay: _follow,
          // A Column with keyed sections rather than a lazy ListView, so a
          // section that arrives late never remounts its neighbours — their
          // bars and tickers would replay from zero.
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
                // Not revealed: this is the name that flew in from the card.
                HeroText(
                  project.name,
                  tag: titleTag(project.id),
                  style: TraceText.screenTitle.copyWith(color: c.textPrimary),
                ),
                if (project.description != null &&
                    project.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TraceSpace.xs),
                    child: Text(
                      project.description!,
                      style: TraceText.rowSubtitle.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ).reveal(0, key: const ValueKey('description')),
                const SizedBox(height: TraceSpace.lg),
                _statusPill(
                  context,
                  status,
                ).reveal(1, key: const ValueKey('status')),
                const SizedBox(height: TraceSpace.xl),
                if (target != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TraceSpace.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: ProgressTrack(
                            value: time.inSeconds / target,
                            delay: _fill,
                          ),
                        ),
                        const SizedBox(width: TraceSpace.md),
                        MonoValue(
                          ((time.inSeconds / target) * 100)
                              .clamp(0, 100)
                              .round(),
                          suffix: '%',
                          style: TraceText.monoSmall,
                          color: c.textPrimary,
                          delay: _fill,
                        ),
                      ],
                    ),
                  ).reveal(2, key: const ValueKey('progress')),
                Row(
                  children: [
                    MonoDuration(
                      time,
                      format: DurationFormat.human,
                      delay: _fill,
                    ),
                    const SizedBox(width: TraceSpace.sm),
                    Text(
                      'total time',
                      style: TraceText.rowSubtitle.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ).reveal(3, key: const ValueKey('total')),
                const SizedBox(height: TraceSpace.section),
                const SectionLabel(
                  'Recent sessions',
                ).reveal(4, key: const ValueKey('sessions-label')),
                const SizedBox(height: TraceSpace.md),
                if (sessions.isEmpty)
                  Text(
                    'No sessions yet.',
                    style: TraceText.body.copyWith(color: c.textSecondary),
                  ).reveal(5, key: const ValueKey('no-sessions'))
                else
                  for (final (i, e) in sessions.take(5).indexed)
                    SessionRow(entry: e).reveal(
                      5 + i,
                      late: RevealLate.expand,
                      key: ValueKey(e.id),
                    ),
                if (sessions.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: TraceSpace.sm),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TraceButton.text(
                        'View all ${sessions.length} sessions',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProjectSessionsScreen(
                              projectId: projectId,
                              name: project.name,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).reveal(10, key: const ValueKey('all-sessions')),
                const SizedBox(height: TraceSpace.section),
                _footer(
                  context,
                  project,
                ).reveal(11, key: const ValueKey('footer')),
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

  Widget _statusPill(BuildContext context, ProjectStatus status) {
    final c = context.traceColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TraceSpace.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: c.navyLight,
          borderRadius: BorderRadius.circular(TraceRadius.pill),
        ),
        child: Text(
          status.label,
          style: TraceText.rowSubtitle.copyWith(color: c.navy),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, Project project) {
    final c = context.traceColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CategoryGlyph(category: Category.build, size: 28),
        const SizedBox(width: TraceSpace.md),
        Expanded(
          child: Text(
            project.description?.isNotEmpty == true
                ? project.description!
                : 'BUILD entries naming this project gather here.',
            style: TraceText.rowSubtitle
                .copyWith(color: c.textSecondary, height: 1.5),
          ),
        ),
      ],
    );
  }
}
