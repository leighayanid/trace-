import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The save confirmation: a hairline that sweeps left to right, then the screen
/// dismisses.
///
/// No checkmark, no bounce, no confetti. The record is the reward — the app
/// should acknowledge a save and get out of the way.
class SaveSweep extends StatelessWidget {
  const SaveSweep({
    super.key,
    required this.active,
    this.color,
    this.height = 1.5,
  });

  /// Flips to true the moment a save begins.
  final bool active;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.traceColors;

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: active ? 1 : 0),
        duration: active ? TraceMotion.base : Duration.zero,
        curve: TraceMotion.enter,
        builder: (context, t, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: t,
            child: Container(color: color ?? c.navy),
          ),
        ),
      ),
    );
  }
}
