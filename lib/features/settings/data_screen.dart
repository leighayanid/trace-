import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../core/export/export_providers.dart';
import '../../core/export/export_service.dart';
import '../../core/export/import_service.dart';
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
  bool _importing = false;
  String? _importMessage;

  /// JSON only: it is the export that carries everything, ids included.
  /// Android matches on MIME type, and a saved export does not always keep
  /// `application/json`, so the looser types are accepted and the contents
  /// decide.
  static const _archiveType = XTypeGroup(
    label: 'TRACE export',
    extensions: ['json'],
    mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
    uniformTypeIdentifiers: ['public.json'],
  );

  Future<void> _import() async {
    if (_importing) return;
    final file = await openFile(acceptedTypeGroups: const [_archiveType]);
    if (file == null || !mounted) return;
    setState(() {
      _importing = true;
      _importMessage = null;
    });

    String message;
    try {
      final outcome = await ref
          .read(importServiceProvider)
          .importJson(await file.readAsString());
      HapticFeedback.selectionClick();
      message = _describe(outcome);
    } on FormatException catch (e) {
      message = e.message;
    } catch (_) {
      message = "Couldn't read that file.";
    }
    if (!mounted) return;
    setState(() {
      _importing = false;
      _importMessage = message;
    });
  }

  static String _describe(ImportOutcome o) {
    if (o.added == 0 && o.updated == 0) {
      return 'Nothing new — this device already had all of it.';
    }
    final parts = [
      if (o.added > 0) '${o.added} added',
      if (o.updated > 0) '${o.updated} updated',
      if (o.kept > 0) '${o.kept} already newer here',
    ];
    return parts.join(' · ');
  }

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
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
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
            const SectionLabel('Import'),
            const SizedBox(height: TraceSpace.md),
            _explain(
              context,
              'Brings a JSON export back in — onto a new phone, or after an '
              'erase. It merges rather than replaces: where this device has a '
              'newer edit, that edit stays, and nothing here is deleted.',
            ),
            const SizedBox(height: TraceSpace.md),
            TraceButton.outlined(
              _importing ? 'Importing…' : 'Import JSON',
              icon: Icons.download_rounded,
              onPressed: _importing ? null : _import,
            ),
            if (_importMessage != null) ...[
              const SizedBox(height: TraceSpace.md),
              Text(
                _importMessage!,
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
