import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/picker_sheet.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_segmented.dart';
import '../../shared/widgets/trace_sheet.dart';
import 'reminder_providers.dart';

/// The one notification TRACE offers, and the switch that turns it off.
///
/// Off until asked for. The screen says plainly what will arrive and what never
/// will, because the reason most trackers are muted is that enabling one
/// notification signs you up for all of them.
class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key});

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  /// Set when the system refuses the ask. Turning the reminder on then leaves
  /// it off, which without a word would look like the switch is broken.
  bool _refused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    final reminder = ref.watch(reminderProvider);

    // Permission can also be withdrawn later, from outside the app, leaving a
    // reminder that is on and silent.
    final blocked = _refused ||
        (reminder.on && !(ref.watch(reminderPermittedProvider).value ?? true));

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
            Text('Reminder',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.md),
            Text(
              'One notification a day, at an hour you pick, asking what you '
              'did. Nothing else arrives — no streaks, no weekly reports, '
              'nothing about the days you missed.',
              style:
                  TraceText.body.copyWith(color: c.textSecondary, height: 1.6),
            ),
            const SizedBox(height: TraceSpace.section),
            TraceSegmented<bool>(
              segments: const {false: 'Off', true: 'On'},
              selected: reminder.on,
              onSelect: _set,
            ),
            if (blocked) ...[
              const SizedBox(height: TraceSpace.md),
              Text(
                'Notifications are turned off for TRACE in your phone’s '
                'settings. The reminder cannot arrive until they are turned '
                'back on there.',
                style: TraceText.rowSubtitle
                    .copyWith(color: c.textSecondary, height: 1.5),
              ),
            ],
            // The time only matters once something is going to arrive.
            AnimatedSize(
              duration: TraceMotion.base,
              curve: TraceMotion.standard,
              alignment: Alignment.topCenter,
              child: reminder.on
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: TraceSpace.section),
                        const SectionLabel('Time'),
                        _timeRow(context, reminder.time),
                        const SizedBox(height: TraceSpace.lg),
                        Text(
                          'A day you have already logged an entry on is '
                          'skipped. The reminder arrives when the day is still '
                          'empty, and not otherwise.',
                          style: TraceText.rowSubtitle
                              .copyWith(color: c.textSecondary, height: 1.5),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRow(BuildContext context, TimeOfDay time) {
    final c = context.traceColors;
    return PressScale(
      onTap: () async {
        final picked = await showReminderTimePicker(context, selected: time);
        if (picked != null) {
          await ref.read(reminderProvider.notifier).selectTime(picked);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TraceSpace.lg),
        child: Row(
          children: [
            Expanded(
              child: Text('Every day at',
                  style: TraceText.body.copyWith(color: c.textPrimary)),
            ),
            Text(time.format(context),
                style: TraceText.mono.copyWith(color: c.textPrimary)),
            const SizedBox(width: TraceSpace.sm),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _set(bool on) async {
    final notifier = ref.read(reminderProvider.notifier);
    if (!on) {
      await notifier.turnOff();
      if (mounted) setState(() => _refused = false);
      return;
    }

    final allowed = await notifier.turnOn();
    if (!mounted) return;
    setState(() => _refused = !allowed);
    if (allowed) {
      HapticFeedback.selectionClick();
      ref.invalidate(reminderPermittedProvider);
    }
  }
}

/// Picks the hour the reminder arrives.
///
/// The evening is one tap, because recording the day belongs at the end of it.
/// Anything else goes through the clock — the same shape as picking a day,
/// where the last week is one tap and older dates go through the calendar.
Future<TimeOfDay?> showReminderTimePicker(
  BuildContext context, {
  required TimeOfDay selected,
}) async {
  const evening = [
    TimeOfDay(hour: 20, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
    TimeOfDay(hour: 22, minute: 0),
  ];

  // A record, so "Another time…" is a distinct answer from dismissing the
  // sheet.
  final picked = await showTraceSheet<({TimeOfDay? time})>(
    context: context,
    builder: (sheetContext) => PickerSheet(
      title: 'Time',
      children: [
        for (final time in evening)
          PickerRow(
            label: time.format(sheetContext),
            selected: time == selected,
            onTap: () => Navigator.of(sheetContext).pop((time: time)),
          ),
        PickerRow(
          label: 'Another time…',
          selected: !evening.contains(selected),
          onTap: () => Navigator.of(sheetContext).pop((time: null)),
        ),
      ],
    ),
  );

  if (picked == null) return null;
  if (picked.time != null) return picked.time;
  if (!context.mounted) return null;

  final c = context.traceColors;
  return showTimePicker(
    context: context,
    initialTime: selected,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: c.navy,
              surface: c.bg,
            ),
      ),
      child: child!,
    ),
  );
}
