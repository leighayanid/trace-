import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/database/database.dart';
import '../../shared/models/category.dart';
import '../../shared/widgets/category_glyph.dart';
import '../../shared/widgets/mono_duration.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/progress_track.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import 'project_providers.dart';
import 'project_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;
    final project = ref.watch(projectByIdProvider(projectId)).value;
    final time = ref.watch(projectTimeProvider(projectId)).value ??
        Duration.zero;
    final sessions = ref.watch(projectSessionsProvider(projectId)).value ??
        const <Entry>[];

    if (project == null) {
      return Scaffold(backgroundColor: c.bg, body: const SizedBox.shrink());
    }

    final status = ProjectStatus.parse(project.status);
    final target = project.targetSecs;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TraceSpace.gutter,
            0,
            TraceSpace.gutter,
            TraceSpace.xxxl,
          ),
          children: [
            _topBar(context),
            Text(project.name,
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: TraceSpace.xs),
              Text(project.description!,
                  style: TraceText.rowSubtitle
                      .copyWith(color: c.textSecondary)),
            ],
            const SizedBox(height: TraceSpace.lg),
            _statusPill(context, status),
            const SizedBox(height: TraceSpace.xl),
            if (target != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ProgressTrack(value: time.inSeconds / target),
                  ),
                  const SizedBox(width: TraceSpace.md),
                  Text(
                    '${((time.inSeconds / target) * 100).clamp(0, 100).round()}%',
                    style: TraceText.monoSmall.copyWith(color: c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: TraceSpace.md),
            ],
            Row(
              children: [
                MonoDuration(time, format: DurationFormat.human),
                const SizedBox(width: TraceSpace.sm),
                Text('total time',
                    style: TraceText.rowSubtitle
                        .copyWith(color: c.textSecondary)),
              ],
            ),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Recent sessions'),
            const SizedBox(height: TraceSpace.md),
            if (sessions.isEmpty)
              Text('No sessions yet.',
                  style: TraceText.body.copyWith(color: c.textSecondary))
            else
              ...sessions.take(5).map((e) => _sessionRow(context, e)),
            if (sessions.length > 5) ...[
              const SizedBox(height: TraceSpace.sm),
              TraceButton.text('View all ${sessions.length} sessions',
                  onPressed: () {}),
            ],
            const SizedBox(height: TraceSpace.section),
            _footer(context, project),
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

  Widget _sessionRow(BuildContext context, Entry e) {
    final c = context.traceColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMM d, yyyy').format(DateTime.parse(e.date)),
              style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
            ),
          ),
          if (e.durationSecs != null)
            MonoDuration(
              Duration(seconds: e.durationSecs!),
              format: DurationFormat.human,
              animate: false,
            ),
        ],
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
