import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Decides *when* to sync, so nobody has to press a button.
///
/// Four triggers, all funnelled through one debounce so a burst of them
/// becomes a single sync:
///
/// - **start** — the app opened, or sync was just switched on
/// - **resume** — back from the background, where another device may have
///   written
/// - **reconnect** — the network returned after being lost
/// - **edit** — a row went dirty; waits for typing to settle first
///
/// Holds no sync logic of its own. Concurrency is the engine's problem, and
/// failure stays quiet exactly as it does for a manual sync.
class AutoSync {
  AutoSync({
    required Future<void> Function() sync,
    required Stream<bool> dirtyChanges,
    required Stream<List<ConnectivityResult>> connectivity,
  }) : _sync = sync {
    _lifecycle = AppLifecycleListener(onResume: () => _schedule(resumeDelay));
    _dirty = dirtyChanges.listen((dirty) {
      if (dirty) _schedule(editDelay);
    });
    _connectivity = connectivity.listen((results) {
      final online = !results.every((r) => r == ConnectivityResult.none);
      if (online && _wasOffline) _schedule(reconnectDelay);
      _wasOffline = !online;
    });
    _schedule(Duration.zero);
  }

  /// Long enough that a run of quick edits syncs once, short enough that a
  /// second device sees them before you have put the phone down.
  static const editDelay = Duration(seconds: 5);

  /// Resume often arrives mid-animation; let the frame settle first.
  static const resumeDelay = Duration(seconds: 1);

  /// A regained connection is usually still negotiating for a moment.
  static const reconnectDelay = Duration(seconds: 2);

  final Future<void> Function() _sync;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<bool> _dirty;
  late final StreamSubscription<List<ConnectivityResult>> _connectivity;
  Timer? _timer;
  bool _wasOffline = false;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// Replaces any pending run. The latest trigger wins, which is right for
  /// every case here: all of them mean "sync soon", none means "sync twice".
  void _schedule(Duration delay) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, _run);
  }

  /// A trigger that lands mid-sync is not dropped: an edit made while a push
  /// was already past its table would otherwise wait for the next trigger,
  /// which might be hours away. It earns exactly one follow-up run.
  Future<void> _run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      await _sync();
    } finally {
      _running = false;
    }
    if (_again) {
      _again = false;
      _schedule(Duration.zero);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _lifecycle.dispose();
    _dirty.cancel();
    _connectivity.cancel();
  }
}
