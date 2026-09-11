import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The one way a sheet opens in TRACE.
///
/// Rises on the emphasized-decelerate curve — most of the travel at once, then
/// a long soft landing — and leaves on emphasized-accelerate, gathering pace
/// as it goes. Material's default sheet uses the same curve both ways, which
/// is what makes default sheets feel mechanical.
Future<T?> showTraceSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  AnimationController? controller,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.32),
    transitionAnimationController: controller,
    sheetAnimationStyle: traceSheetAnimationStyle,
    builder: builder,
  );
}

/// Durations are ignored when a [showTraceSheet] `controller` is supplied —
/// the controller's own durations win — but the curves always apply.
///
/// Const on purpose: the sheet asserts its curves are identical across
/// rebuilds, and a `.flipped` built per call would not be.
const traceSheetAnimationStyle = AnimationStyle(
  duration: TraceMotion.sheet,
  reverseDuration: TraceMotion.sheetReverse,
  curve: TraceMotion.emphasizedDecelerate,
  reverseCurve: FlippedCurve(TraceMotion.emphasizedAccelerate),
);
