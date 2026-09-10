/// What to do with a row that arrived from the server.
enum Resolution {
  /// Write the remote row over the local one.
  takeRemote,

  /// Keep the local row; it is dirty and newer, and still needs pushing.
  keepLocal,
}

/// The minimum a row must expose to be reconciled.
class SyncRow {
  const SyncRow({
    required this.id,
    required this.updatedAt,
    required this.dirty,
  });

  final String id;
  final DateTime updatedAt;

  /// True when the local row has unsynced changes.
  final bool dirty;
}

/// Per-row last-write-wins.
///
/// Correct and boring for one user across a handful of their own devices, which
/// is exactly the situation TRACE is in. CRDTs would be ceremony here.
///
/// Isolated from all I/O so the rules below can be tested directly — this is the
/// logic that silently eats edits when it is wrong.
abstract final class Conflict {
  /// Guards against a device with a skewed clock winning every conflict
  /// forever.
  static const maxSkew = Duration(minutes: 5);

  /// [local] is null when the row has never been seen on this device.
  static Resolution resolve({
    required SyncRow? local,
    required DateTime remoteUpdatedAt,
  }) {
    // Never seen locally: nothing to lose by taking it.
    if (local == null) return Resolution.takeRemote;

    // A clean row has no local edit worth protecting. Taking remote also
    // repairs a row that drifted out of sync for any other reason.
    if (!local.dirty) return Resolution.takeRemote;

    // Both sides changed. The later edit wins; ties go to the server so two
    // devices converge on the same answer instead of ping-ponging.
    return local.updatedAt.isAfter(remoteUpdatedAt)
        ? Resolution.keepLocal
        : Resolution.takeRemote;
  }

  /// Clamps a client timestamp that is implausibly far ahead of the server.
  ///
  /// Without this, one device with a wrong clock wins every conflict until its
  /// clock is fixed — and the user just sees edits disappearing.
  static DateTime clampToServer(DateTime clientTime, DateTime serverNow) {
    final ceiling = serverNow.add(maxSkew);
    return clientTime.isAfter(ceiling) ? ceiling : clientTime;
  }

  /// The next pull cursor: the newest `updated_at` actually received.
  ///
  /// Returns [current] for an empty page, so a pull that returns nothing cannot
  /// rewind the cursor and re-download history on every sync.
  static DateTime? advanceCursor({
    required DateTime? current,
    required Iterable<DateTime> received,
  }) {
    var next = current;
    for (final t in received) {
      if (next == null || t.isAfter(next)) next = t;
    }
    return next;
  }
}
