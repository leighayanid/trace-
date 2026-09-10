import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_providers.dart';

/// How an erase ended. The sheet says exactly this and nothing more.
enum EraseOutcome {
  /// Gone from this device, and from the server if there was one.
  erased,

  /// Gone from view here, but the deletion has not reached the server yet.
  ///
  /// The rows stay on disk as tombstones so the next successful sync can carry
  /// them. Hard-deleting instead would leave the server copy alive and pull it
  /// straight back on the next cold start.
  pendingSync,
}

/// Deleting everything, honestly.
///
/// The order matters and is the whole point: tombstone, push, *then* erase. A
/// local wipe that skips the push is not a deletion — it is a deletion that
/// undoes itself the next time the device syncs.
class EraseController {
  const EraseController(this._ref);

  final Ref _ref;

  Future<EraseOutcome> eraseEverything() async {
    final db = _ref.read(databaseProvider);
    final signedIn = await _ref.read(signedInProvider.future);

    if (!signedIn) {
      // No server, nowhere for a tombstone to travel. Straight to disk.
      await db.eraseEverything();
      return EraseOutcome.erased;
    }

    await db.tombstoneEverything();
    final status = await _ref.read(syncEngineProvider).sync();
    if (status is SyncFailed) return EraseOutcome.pendingSync;

    await db.eraseEverything();
    return EraseOutcome.erased;
  }
}

final eraseControllerProvider =
    Provider<EraseController>(EraseController.new);
