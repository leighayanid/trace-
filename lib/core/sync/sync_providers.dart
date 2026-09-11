import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/neon_auth_client.dart';
import '../auth/session_controller.dart';
import '../auth/token_store.dart';
import '../config.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import 'auto_sync.dart';
import 'data_api_client.dart';
import 'sync_engine.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => const TokenStore());

final neonAuthClientProvider = Provider<NeonAuthClient>((ref) {
  final client = NeonAuthClient(
    baseUrl: TraceConfig.authBaseUrl,
    origin: TraceConfig.authOrigin,
  );
  ref.onDispose(client.dispose);
  return client;
});

final sessionControllerProvider = Provider<SessionController>((ref) {
  final auth = ref.watch(neonAuthClientProvider);
  final store = ref.watch(tokenStoreProvider);
  return SessionController(
    fetchJwt: auth.fetchJwt,
    readSession: store.readSession,
  );
});

final dataApiClientProvider = Provider<DataApiClient>((ref) {
  return DataApiClient(
    dataApiUrl: TraceConfig.dataApiUrl,
    session: ref.watch(sessionControllerProvider),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(databaseProvider),
    api: ref.watch(dataApiClientProvider),
  );
});

/// Whether a session token exists on this device.
///
/// Not a claim that the token is still valid — only the server can say that.
/// It decides which UI to show, nothing more.
final signedInProvider = FutureProvider<bool>((ref) async {
  final token = await ref.watch(tokenStoreProvider).readSession();
  return token != null && token.isNotEmpty;
});

final syncStateProvider = StreamProvider<SyncState?>(
  (ref) => ref.watch(databaseProvider).watchSyncState(),
);

/// Drives the sync screen. Kept out of SyncEngine so the engine stays free of
/// UI concerns and remains testable without Flutter.
class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncIdle(null);

  Future<void> syncNow() async {
    state = const SyncRunning();
    final result = await ref.read(syncEngineProvider).sync();
    // A dead session is cleared rather than left to fail on every trigger:
    // the Sync screen falls back to its sign-in form, and auto-sync stops.
    if (result is SyncFailed && result.sessionEnded) await _forgetSession();
    state = result;
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final token = await ref
          .read(neonAuthClientProvider)
          .signIn(email: email, password: password);
      await ref.read(tokenStoreProvider).writeSession(token);
      ref.invalidate(signedInProvider);
      await syncNow();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the sign-in service';
    }
  }

  Future<void> signOut() async {
    final token = await ref.read(tokenStoreProvider).readSession();
    if (token != null) {
      await ref.read(neonAuthClientProvider).signOut(token);
    }
    // Cleared even if the network call failed — a sign-out that leaves the
    // token on disk is not a sign-out.
    await _forgetSession();
    state = const SyncIdle(null);
  }

  Future<void> _forgetSession() async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(sessionControllerProvider).invalidate();
    ref.invalidate(signedInProvider);
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Keeps sync running in the background while signed in. Watched once, by the
/// app root; rebuilt — and so started or stopped — as sign-in state changes.
final autoSyncProvider = Provider<void>((ref) {
  if (!TraceConfig.syncConfigured) return;
  if (!(ref.watch(signedInProvider).value ?? false)) return;

  final auto = AutoSync(
    sync: () => ref.read(syncControllerProvider.notifier).syncNow(),
    dirtyChanges: ref.watch(databaseProvider).watchHasDirtyRows(),
    connectivity: Connectivity().onConnectivityChanged,
  );
  ref.onDispose(auto.dispose);
});
