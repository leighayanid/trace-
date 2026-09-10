import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A deliberately plain stand-in for a screen not yet built.
///
/// Kept visually quiet on purpose: a placeholder that looks half-designed is
/// harder to read as unfinished than one that clearly is.
class PhasePlaceholder extends StatelessWidget {
  const PhasePlaceholder({
    super.key,
    required this.title,
    required this.phase,
  });

  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TraceSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: TraceSpace.lg),
              Text(
                title,
                style: TraceText.screenTitle.copyWith(color: c.textPrimary),
              ),
              const Spacer(),
              Center(
                child: Text(
                  phase,
                  style: TraceText.sectionLabel.copyWith(color: c.textSecondary),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
