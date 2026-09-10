import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../../core/config.dart';
import '../insights/insights_screen.dart';
import '../reading/reading_screen.dart';
import 'about_screen.dart';
import 'data_screen.dart';
import 'sync_screen.dart';

/// Secondary destinations. A flat list, one level deep — the brief rules out a
/// multi-level navigation system.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TraceSpace.gutter,
            TraceSpace.lg,
            TraceSpace.gutter,
            TraceSpace.xxxl,
          ),
          children: [
            Text('More',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.section),
            _row(context, Icons.menu_book_outlined, 'Reading',
                const ReadingScreen()),
            Divider(color: c.border, height: 1),
            _row(context, Icons.insights_outlined, 'Insights',
                const InsightsScreen()),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Data'),
            const SizedBox(height: TraceSpace.xs),
            _row(context, Icons.download_outlined, 'Export and delete',
                const DataScreen()),
            // Sync is hidden entirely unless a backend is configured. A row
            // that cannot work is worse than no row — and the local-first app
            // is complete without one.
            if (TraceConfig.syncConfigured) ...[
              Divider(color: c.border, height: 1),
              _row(context, Icons.cloud_outlined, 'Sync', const SyncScreen()),
            ],
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('About'),
            const SizedBox(height: TraceSpace.xs),
            _row(context, Icons.info_outline_rounded, 'How TRACE works',
                const AboutScreen()),
          ],
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
