import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/export/export_providers.dart';
import '../../core/export/export_service.dart';
import '../../core/sync/sync_providers.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';
import 'erase_sheet.dart';

/// Take the record with you, or end it.
///
/// Both halves of the privacy promise live on one screen so neither has to be
/// hunted for: export exists because a record you cannot take out is not
/// yours, and erase exists because a record you cannot end is not private.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  ExportFormat? _busy;
  String? _message;

  Future<void> _export(ExportFormat format) async {
    if (_busy != null) return;
    setState(() {
      _busy = format;
      _message = null;
    });

    // iPad anchors the share popover to this rectangle; without it the sheet
    // points at the middle of the screen.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    try {
      final outcome =
          await ref.read(exportServiceProvider).export(format, sharePositionOrigin: origin);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _busy = null;
        _message = outcome.rows == 0
            ? 'Nothing to export yet.'
            : '${outcome.fileName} · ${outcome.rows} '
                '${outcome.rows == 1 ? 'row' : 'rows'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _message = 'Export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final signedIn = ref.watch(signedInProvider).value ?? false;

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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TraceSpace.md),
              child: PressScale(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.chevron_left_rounded,
                    size: 26, color: c.textPrimary),
              ),
            ),
            Text('Your data',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.md),
            Text(
              'Your record lives in a SQLite file on this device. You can take '
              'a copy of it at any time, in a format nothing but you needs to '
              'be able to read.',
              style:
                  TraceText.body.copyWith(color: c.textSecondary, height: 1.6),
            ),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Export'),
            const SizedBox(height: TraceSpace.md),
            _explain(
              context,
              'JSON is everything — entries, projects, books and notes, with '
              'their ids intact. It is the copy to keep.',
            ),
            const SizedBox(height: TraceSpace.md),
            TraceButton.outlined(
              _busy == ExportFormat.json ? 'Preparing…' : 'Export JSON',
              icon: Icons.data_object_rounded,
              onPressed: _busy != null ? null : () => _export(ExportFormat.json),
            ),
            const SizedBox(height: TraceSpace.xl),
            _explain(
              context,
              'CSV is entries only, with projects and books resolved to their '
              'names. It is the copy to read in a spreadsheet.',
            ),
            const SizedBox(height: TraceSpace.md),
            TraceButton.outlined(
              _busy == ExportFormat.csv ? 'Preparing…' : 'Export CSV',
              icon: Icons.table_rows_outlined,
              onPressed: _busy != null ? null : () => _export(ExportFormat.csv),
            ),
            // One muted line, replaced on the next export. No banner, no toast
            // stack, nothing that needs dismissing.
            if (_message != null) ...[
              const SizedBox(height: TraceSpace.md),
              Text(
                _message!,
                style: TraceText.rowSubtitle.copyWith(color: c.textSecondary),
              ),
            ],
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Erase'),
            const SizedBox(height: TraceSpace.md),
            _explain(
              context,
              signedIn
                  ? 'Deletes every entry, project, book and note from this '
                      'device and from your database. Export first — this '
                      'cannot be undone.'
                  : 'Deletes every entry, project, book and note from this '
                      'device. Export first — this cannot be undone.',
            ),
            const SizedBox(height: TraceSpace.md),
            TraceButton.outlined(
              'Delete all data',
              icon: Icons.delete_outline_rounded,
              onPressed: () => EraseSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explain(BuildContext context, String text) {
    final c = context.traceColors;
    return Text(
      text,
      style: TraceText.rowSubtitle.copyWith(color: c.textSecondary, height: 1.5),
    );
  }
}
