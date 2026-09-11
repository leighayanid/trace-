import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/auth/neon_auth_client.dart';
import 'package:trace/core/auth/session_controller.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/sync/auto_sync.dart';
import 'package:trace/core/sync/data_api_client.dart';
import 'package:trace/core/sync/sync_engine.dart';

/// When sync happens without a button, and what happens when the session is
/// gone. Timers run on the test clock, so every delay here is exact.
void main() {
  late StreamController<bool> dirty;
  late StreamController<List<ConnectivityResult>> network;
  late int runs;

  AutoSync start({Future<void> Function()? sync}) {
    final auto = AutoSync(
      sync: sync ?? () async => runs++,
      dirtyChanges: dirty.stream,
      connectivity: network.stream,
    );
    addTearDown(auto.dispose);
    return auto;
  }

  setUp(() {
    dirty = StreamController<bool>();
    network = StreamController<List<ConnectivityResult>>();
    runs = 0;
  });

  testWidgets('syncs once on start', (tester) async {
    start();
    await tester.pump(Duration.zero);
    expect(runs, 1);
  });

  testWidgets('a burst of edits becomes one sync, after they settle',
      (tester) async {
    start();
    await tester.pump(Duration.zero);
    runs = 0;

    for (var i = 0; i < 3; i++) {
      dirty.add(true);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(runs, 0, reason: 'still typing');

    await tester.pump(AutoSync.editDelay);
    expect(runs, 1);
  });

  testWidgets('a clean database does not trigger a sync', (tester) async {
    start();
    await tester.pump(Duration.zero);
    runs = 0;

    dirty.add(false);
    await tester.pump(AutoSync.editDelay * 2);
    expect(runs, 0);
  });

  testWidgets('syncs when the network comes back, not while it stays up',
      (tester) async {
    start();
    await tester.pump(Duration.zero);
    runs = 0;

    network.add([ConnectivityResult.wifi]);
    await tester.pump(AutoSync.reconnectDelay * 2);
    expect(runs, 0, reason: 'was never offline');

    network.add([ConnectivityResult.none]);
    await tester.pump(Duration.zero);
    network.add([ConnectivityResult.mobile]);
    await tester.pump(AutoSync.reconnectDelay);
    expect(runs, 1);
  });

  testWidgets('syncs on resume', (tester) async {
    start();
    await tester.pump(Duration.zero);
    runs = 0;

    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(AutoSync.resumeDelay);
    expect(runs, 1);
  });

  testWidgets('an edit during a sync earns exactly one follow-up',
      (tester) async {
    final gate = Completer<void>();
    start(sync: () async {
      runs++;
      if (runs == 1) await gate.future;
    });
    await tester.pump(Duration.zero);
    expect(runs, 1, reason: 'first sync is in flight');

    dirty.add(true);
    await tester.pump(AutoSync.editDelay);
    dirty.add(true);
    await tester.pump(AutoSync.editDelay);
    expect(runs, 1, reason: 'held until the first finishes');

    gate.complete();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(runs, 2);
  });

  testWidgets('nothing fires after dispose', (tester) async {
    final auto = start();
    await tester.pump(Duration.zero);
    runs = 0;

    dirty.add(true);
    await tester.pump(Duration.zero);
    auto.dispose();
    await tester.pump(AutoSync.editDelay * 2);
    expect(runs, 0);
  });

  group('SyncEngine', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    SyncEngine engineWhoseTokenExchangeFails(int status) => SyncEngine(
          db: db,
          api: DataApiClient(
            dataApiUrl: 'https://example.invalid/rest/v1',
            session: SessionController(
              readSession: () async => 'session_token=x',
              fetchJwt: (_) async =>
                  throw AuthException('refused', statusCode: status),
            ),
          ),
        );

    test('a refused session is reported as ended', () async {
      final result = await engineWhoseTokenExchangeFails(401).sync();

      expect(result, isA<SyncFailed>());
      expect((result as SyncFailed).sessionEnded, isTrue);
      expect(result.message, 'Signed out — sign in again');
    });

    test('any other auth failure leaves the session alone', () async {
      final result = await engineWhoseTokenExchangeFails(503).sync();

      expect((result as SyncFailed).sessionEnded, isFalse);
    });
  });
}
