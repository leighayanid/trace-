import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/theme.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_providers.dart';
import '../../shared/widgets/press_scale.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/trace_button.dart';

/// Sync is opt-in and framed as a choice, never as a gate.
///
/// Everything in TRACE works before this screen is ever opened; signing in adds
/// a second device, and nothing else.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(syncControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
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
            Text('Sync',
                style: TraceText.screenTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: TraceSpace.md),
            Text(
              'TRACE works entirely on this device. Signing in copies your '
              'record to your own Neon database so a second device can read '
              'it. Nothing is shared with anyone.',
              style: TraceText.body
                  .copyWith(color: c.textSecondary, height: 1.6),
            ),
            const SizedBox(height: TraceSpace.section),
            if (signedIn)
              ..._signedInSection(context)
            else
              ..._signInSection(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _signInSection(BuildContext context) {
    final c = context.traceColors;
    final status = ref.watch(syncControllerProvider);
    // Why the form is back, when it came back on its own. A sign-in attempt's
    // own error takes precedence.
    final notice = _error ??
        (status is SyncFailed && status.sessionEnded
            ? 'Your session ended. Sign in again to keep syncing — nothing '
                'on this device was lost.'
            : null);

    return [
      const SectionLabel('Sign in'),
      const SizedBox(height: TraceSpace.md),
      _field(context, _email, 'Email',
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: TraceSpace.md),
      _field(context, _password, 'Password', obscure: true),
      if (notice != null) ...[
        const SizedBox(height: TraceSpace.md),
        Text(notice,
            style: TraceText.rowSubtitle.copyWith(color: c.textPrimary)),
      ],
      const SizedBox(height: TraceSpace.xl),
      TraceButton(
        _busy ? 'Signing in…' : 'Sign in',
        onPressed: _busy ? null : _signIn,
      ),
    ];
  }

  List<Widget> _signedInSection(BuildContext context) {
    final c = context.traceColors;
    final status = ref.watch(syncControllerProvider);
    final state = ref.watch(syncStateProvider).value;

    return [
      const SectionLabel('Status'),
      const SizedBox(height: TraceSpace.md),
      Text(
        switch (status) {
          SyncRunning() => 'Syncing…',
          SyncFailed(:final message) => message,
          SyncIdle() => state?.lastPushAt == null
              ? 'Not synced yet'
              : 'Last synced ${_ago(state!.lastPushAt!)}',
        },
        style: TraceText.body.copyWith(color: c.textPrimary),
      ),
      // A past failure stays visible as one muted line, and nothing more.
      // No banner, no modal, no red.
      if (state?.lastError != null && status is! SyncFailed) ...[
        const SizedBox(height: TraceSpace.xs),
        Text('Last attempt: ${state!.lastError}',
            style: TraceText.rowSubtitle.copyWith(color: c.textSecondary)),
      ],
      const SizedBox(height: TraceSpace.xl),
      TraceButton(
        status is SyncRunning ? 'Syncing…' : 'Sync now',
        onPressed: status is SyncRunning
            ? null
            : () => ref.read(syncControllerProvider.notifier).syncNow(),
      ),
      const SizedBox(height: TraceSpace.md),
      TraceButton.outlined(
        'Sign out',
        onPressed: () => ref.read(syncControllerProvider.notifier).signOut(),
      ),
      const SizedBox(height: TraceSpace.sm),
      Text(
        'Signing out clears the token from this device. Your entries stay '
        'here — nothing local is deleted.',
        style: TraceText.rowSubtitle
            .copyWith(color: c.textSecondary, height: 1.5),
      ),
    ];
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    final c = context.traceColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TraceSpace.md,
        vertical: TraceSpace.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(TraceRadius.card),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        autocorrect: false,
        enableSuggestions: false,
        style: TraceText.body.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TraceText.body.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return 'on ${DateFormat('MMM d').format(t.toLocal())}';
  }
}
