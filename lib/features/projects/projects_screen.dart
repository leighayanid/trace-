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
import 'project_detail_screen.dart';
import 'project_providers.dart';
import 'new_project_sheet.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final projects = ref.watch(projectsProvider);

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
                  Text('Projects',
                      style:
                          TraceText.screenTitle.copyWith(color: c.textPrimary)),
                  PressScale(
                    onTap: () => NewProjectSheet.show(context),
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
                child: projects.when(
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

  /// Built eagerly, not lazily: a personal list of projects is short, and a
  /// lazy list rebuilds rows as they scroll back in — which would be
  /// indistinguishable from a project just created, and replay its arrival.
  Widget _list(BuildContext context, List<Project> projects) {
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
          for (var i = 0; i < projects.length; i++)
            // A project created from the sheet opens its own space.
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : TraceSpace.xl),
              child: _ProjectCard(project: projects[i], index: i),
            ).reveal(
              i.clamp(0, 7),
              late: RevealLate.expand,
              key: ValueKey(projects[i].id),
            ),
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
          'No projects yet.\nAdd one and BUILD entries will gather under it.',
          textAlign: TextAlign.center,
          style: TraceText.body.copyWith(color: c.textSecondary, height: 1.6),
        ),
      ).reveal(0),
    );
  }

  Widget _error(BuildContext context) {
    final c = context.traceColors;
    return Center(
      child: Text("Couldn't read projects.",
          style: TraceText.body.copyWith(color: c.textSecondary)),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, required this.index});

  final Project project;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final time =
        ref.watch(projectTimeProvider(project.id)).value ?? Duration.zero;
    final target = project.targetSecs;
    // Segments count out once the card itself has landed.
    final fill = Duration(milliseconds: 55 * index.clamp(0, 7) + 260);

    return PressScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ProjectDetailScreen(projectId: project.id, initial: project),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // Grows into the detail screen's title as it opens.
                child: HeroText(
                  project.name,
                  tag: ProjectDetailScreen.titleTag(project.id),
                  style: TraceText.bookTitle.copyWith(color: c.textPrimary),
                ),
              ),
              // A percentage appears only against a target the user set.
              // Without one there is nothing honest to be a percentage of.
              if (target != null)
                MonoValue(
                  ((time.inSeconds / target) * 100).clamp(0, 100).round(),
                  suffix: '%',
                  style: TraceText.monoSmall,
                  color: c.textPrimary,
                  delay: fill,
                ),
            ],
          ),
          const SizedBox(height: TraceSpace.md),
          if (target != null) ...[
            SegmentedTrack(value: time.inSeconds / target, delay: fill),
            const SizedBox(height: TraceSpace.md),
          ],
          MonoDuration(
            time,
            format: DurationFormat.human,
            color: c.textSecondary,
            animate: false,
          ),
        ],
      ),
    );
  }
}
