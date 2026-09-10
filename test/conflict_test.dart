import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/sync/conflict.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12, 0);
  final earlier = t0.subtract(const Duration(minutes: 10));
  final later = t0.add(const Duration(minutes: 10));

  SyncRow row({required DateTime updatedAt, required bool dirty}) =>
      SyncRow(id: 'e1', updatedAt: updatedAt, dirty: dirty);

  group('Conflict.resolve', () {
    test('a row never seen locally is taken', () {
      expect(
        Conflict.resolve(local: null, remoteUpdatedAt: t0),
        Resolution.takeRemote,
      );
    });

    test('a clean local row yields, even when it is newer', () {
      // Nothing local is at risk: a clean row has no unsynced edit, so taking
      // remote also repairs drift.
      expect(
        Conflict.resolve(
          local: row(updatedAt: later, dirty: false),
          remoteUpdatedAt: earlier,
        ),
        Resolution.takeRemote,
      );
    });

    test('a dirty local row that is newer is kept', () {
      expect(
        Conflict.resolve(
          local: row(updatedAt: later, dirty: true),
          remoteUpdatedAt: earlier,
        ),
        Resolution.keepLocal,
      );
    });

    test('a dirty local row that is older loses', () {
      expect(
        Conflict.resolve(
          local: row(updatedAt: earlier, dirty: true),
          remoteUpdatedAt: later,
        ),
        Resolution.takeRemote,
      );
    });

    test('an exact tie goes to the server, so devices converge', () {
      // If ties went local, two devices could each keep their own copy and
      // push forever.
      expect(
        Conflict.resolve(
          local: row(updatedAt: t0, dirty: true),
          remoteUpdatedAt: t0,
        ),
        Resolution.takeRemote,
      );
    });
  });

  group('Conflict.clampToServer', () {
    test('leaves a plausible client time alone', () {
      final client = t0.add(const Duration(minutes: 1));
      expect(Conflict.clampToServer(client, t0), client);
    });

    test('leaves a client running behind alone', () {
      expect(Conflict.clampToServer(earlier, t0), earlier);
    });

    test('clamps a client running far ahead', () {
      // Otherwise one device with a wrong clock wins every conflict, and the
      // user just sees edits vanish.
      final wild = t0.add(const Duration(days: 400));
      expect(Conflict.clampToServer(wild, t0), t0.add(Conflict.maxSkew));
    });

    test('allows exactly the skew ceiling', () {
      final edge = t0.add(Conflict.maxSkew);
      expect(Conflict.clampToServer(edge, t0), edge);
    });
  });

  group('Conflict.advanceCursor', () {
    test('takes the newest timestamp received', () {
      expect(
        Conflict.advanceCursor(
          current: earlier,
          received: [t0, later, earlier],
        ),
        later,
      );
    });

    test('an empty page does not rewind the cursor', () {
      // A rewind would re-download the whole history on every idle sync.
      expect(
        Conflict.advanceCursor(current: t0, received: const []),
        t0,
      );
    });

    test('never moves backwards', () {
      expect(
        Conflict.advanceCursor(current: later, received: [earlier, t0]),
        later,
      );
    });

    test('starts from nothing on a first sync', () {
      expect(
        Conflict.advanceCursor(current: null, received: [earlier, t0]),
        t0,
      );
    });
  });
}
