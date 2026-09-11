import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';

/// Explains the only number in TRACE that could be mistaken for a score.
///
/// If Presence cannot be stated plainly on this screen, it should not exist.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

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
            Text('How TRACE works',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Presence'),
            const SizedBox(height: TraceSpace.md),
            _para(
              context,
              'Presence is the share of the four categories you touched today: '
              'one category is 25%, all four is 100%.',
            ),
            _para(
              context,
              'It measures the breadth of a day, not how much you did. Four '
              'BUILD entries count the same as one. It is not a score, it '
              'cannot be improved by working harder, and nothing in TRACE '
              'compares it to anyone else.',
            ),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Days, not streaks'),
            const SizedBox(height: TraceSpace.md),
            _para(
              context,
              'Insights counts days present — "16 days" — rather than '
              'consecutive ones. A missed day is a fact about the record, not '
              'a broken chain.',
            ),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Percentages'),
            const SizedBox(height: TraceSpace.md),
            _para(
              context,
              'A project shows a percentage only when you have set a target '
              'for it. Without a target there is nothing honest for a '
              'percentage to be of, so only tracked time is shown.',
            ),
            const SizedBox(height: TraceSpace.section),
            const SectionLabel('Your data'),
            const SizedBox(height: TraceSpace.md),
            _para(
              context,
              'Everything lives in a SQLite database on this device. No '
              'account is required, and nothing leaves the phone unless you '
              'later turn on sync.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _para(BuildContext context, String text) {
    final c = context.traceColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: TraceSpace.md),
      child: Text(
        text,
        style: TraceText.body.copyWith(color: c.textSecondary, height: 1.6),
      ),
    );
  }
}
