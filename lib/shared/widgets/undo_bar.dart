import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// One quiet line after a delete, with a way back.
///
/// Deletes in TRACE are tombstones, so undoing one is cheap and always
/// possible; this just makes it visible for the few seconds it matters. The bar
/// is inverted text on the page colour's opposite — no colour, no icon.
void showUndo(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final c = context.traceColors;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        elevation: 0,
        backgroundColor: c.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TraceRadius.card),
        ),
        content: Text(message, style: TraceText.body.copyWith(color: c.bg)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: c.bg,
          onPressed: onUndo,
        ),
      ),
    );
}
