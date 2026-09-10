import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/neon_auth_client.dart';
import '../auth/session_controller.dart';
import '../auth/token_store.dart';
import '../config.dart';
import '../database/database.dart';
import '../database/database_provider.dart';
import 'data_api_client.dart';
import 'sync_engine.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => const TokenStore());

final neonAuthClientProvider = Provider<NeonAuthClient>((ref) {
  final client = NeonAuthClient(baseUrl: TraceConfig.authBaseUrl);
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
    state = await ref.read(syncEngineProvider).sync();
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
    final store = ref.read(tokenStoreProvider);
    final token = await store.readSession();
    if (token != null) {
      await ref.read(neonAuthClientProvider).signOut(token);
    }
    // Cleared even if the network call failed — a sign-out that leaves the
    // token on disk is not a sign-out.
    await store.clear();
    ref.read(sessionControllerProvider).invalidate();
    ref.invalidate(signedInProvider);
    state = const SyncIdle(null);
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);
