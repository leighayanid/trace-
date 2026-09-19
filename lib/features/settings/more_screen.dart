import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../git/import_commits_screen.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/theme_mode.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/reveal.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_segmented.dart';
import '../../core/config.dart';
import '../insights/insights_screen.dart';
import '../reading/reading_screen.dart';
import 'about_screen.dart';
import 'data_screen.dart';
import 'sync_screen.dart';

/// Secondary destinations. A flat list, one level deep — the brief rules out a
/// multi-level navigation system.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.traceColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        // Groups arrive in reading order the first time the tab is opened.
        child: RevealScope(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.gutter,
              TraceSpace.lg,
              context.gutter,
              TraceSpace.xxxl,
            ),
            children: [
              Text('More',
                      style:
                          TraceText.screenTitle.copyWith(color: c.textPrimary))
                  .reveal(0),
              const SizedBox(height: TraceSpace.section),
              Column(
                children: [
                  _row(context, Icons.menu_book_outlined, 'Reading',
                      const ReadingScreen()),
                  Divider(color: c.border, height: 1),
                  _row(context, Icons.insights_outlined, 'Insights',
                      const InsightsScreen()),
                ],
              ).reveal(1),
              const SizedBox(height: TraceSpace.section),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Appearance'),
                  const SizedBox(height: TraceSpace.md),
                  // Inline rather than a screen of its own: three choices do
                  // not earn a destination.
                  TraceSegmented<ThemeMode>(
                    segments: const {
                      ThemeMode.system: 'System',
                      ThemeMode.light: 'Light',
                      ThemeMode.dark: 'Dark',
                    },
                    selected: ref.watch(themeModeProvider),
                    onSelect: ref.read(themeModeProvider.notifier).select,
                  ),
                ],
              ).reveal(2),
              const SizedBox(height: TraceSpace.section),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Data'),
                  const SizedBox(height: TraceSpace.xs),
                  _row(context, Icons.download_outlined, 'Export and delete',
                      const DataScreen()),
                  Divider(color: c.border, height: 1),
                  _row(context, Icons.commit_rounded, 'Import commits',
                      const ImportCommitsScreen()),
                  // Sync is hidden entirely unless a backend is configured. A
                  // row that cannot work is worse than no row — and the
                  // local-first app is complete without one.
                  if (TraceConfig.syncConfigured) ...[
                    Divider(color: c.border, height: 1),
                    _row(context, Icons.cloud_outlined, 'Sync',
                        const SyncScreen()),
                  ],
                ],
              ).reveal(3),
              const SizedBox(height: TraceSpace.section),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('About'),
                  const SizedBox(height: TraceSpace.xs),
                  _row(context, Icons.info_outline_rounded, 'How TRACE works',
                      const AboutScreen()),
                ],
              ).reveal(4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, Widget destination) {
    final c = context.traceColors;
    return PressScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => destination),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TraceSpace.lg),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.textSecondary),
            const SizedBox(width: TraceSpace.md),
            Expanded(
              child: Text(label,
                  style: TraceText.body.copyWith(color: c.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
