import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/core/sync/data_api_client.dart';
import 'package:trace/core/sync/sync_engine.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;
  late AppDatabase phone;
  late AppDatabase tablet;
  late SyncEngine phoneSync;
  late SyncEngine tabletSync;

  setUp(() {
    server = FakeServer();
    phone = AppDatabase.forTesting(NativeDatabase.memory());
    tablet = AppDatabase.forTesting(NativeDatabase.memory());
    phoneSync = SyncEngine(db: phone, api: server);
    tabletSync = SyncEngine(db: tablet, api: server);
  });

  tearDown(() async {
    await phone.close();
    await tablet.close();
  });

  DateTime at(int hour) => DateTime.utc(2026, 9, 18, hour);

  Future<void> addEntry(
    AppDatabase db,
    String id,
    DateTime when, {
    String title = 'Walk',
  }) => db.upsertEntry(
    EntriesCompanion.insert(
      id: id,
      category: 'life',
      title: title,
      date: '2026-09-18',
      createdAt: when,
      updatedAt: when,
    ),
  );

  Future<void> addProject(AppDatabase db, String id, DateTime when) =>
      db.upsertProject(
        ProjectsCompanion.insert(
          id: id,
          name: 'TRACE',
          createdAt: when,
          updatedAt: when,
        ),
      );

  Future<void> retitle(
    AppDatabase db,
    String id,
    String title,
    DateTime when,
  ) => db.updateEntry(
    EntriesCompanion(
      id: Value(id),
      title: Value(title),
      updatedAt: Value(when),
      dirty: const Value(true),
    ),
  );

  Future<void> sync(SyncEngine engine) async {
    final result = await engine.sync();
    expect(result, isA<SyncIdle>(), reason: '$result');
  }

  test(
    'a newer row in one table does not hide an older row in the next',
    () async {
      // Projects are pulled before entries. With one shared timestamp cursor,
      // the project at 14:00 moved it past the entry at 09:00.
      await addEntry(phone, 'e1', at(9));
      await addProject(phone, 'p1', at(14));
      await sync(phoneSync);

      await sync(tabletSync);

      expect(await tablet.findEntry('e1'), isNotNull);
      expect(await tablet.pullCursor('projects'), isNotNull);
      expect(await tablet.pullCursor('entries'), isNotNull);
    },
  );

  test(
    'an edit synced late still reaches a device that synced in between',
    () async {
      // Made offline on the phone at 10:00, not synced yet.
      await addEntry(phone, 'offline', at(10));

      // Meanwhile the tablet records something at 12:00 and syncs, moving its
      // cursor past 10:00 — the point where a timestamp cursor lost the row.
      await addEntry(tablet, 'noon', at(12));
      await sync(tabletSync);

      await sync(phoneSync);
      await sync(tabletSync);

      expect(await tablet.findEntry('offline'), isNotNull);
      expect(await phone.findEntry('noon'), isNotNull);
    },
  );

  test(
    'a stale push does not overwrite a newer edit, and both devices converge',
    () async {
      await addEntry(phone, 'e1', at(9), title: 'Walk');
      await sync(phoneSync);
      await sync(tabletSync);

      await retitle(tablet, 'e1', 'Long walk', at(12));
      await sync(tabletSync);

      // The phone edited earlier but syncs later.
      await retitle(phone, 'e1', 'Short walk', at(11));
      await sync(phoneSync);

      expect(server.rows('entries')['e1']!['title'], 'Long walk');
      final onPhone = (await phone.findEntry('e1'))!;
      expect(onPhone.title, 'Long walk');
      expect(onPhone.dirty, isFalse);
    },
  );

  test(
    'every tombstone arrives when more than a page share one timestamp',
    () async {
      // Delete-all stamps every row with the same instant. Paging by
      // `updated_at > cursor` stopped after the first page.
      const count = DataApiClient.pageSize * 2 + 1;
      await phone.batch(
        (b) => b.insertAll(phone.entries, [
          for (var i = 0; i < count; i++)
            EntriesCompanion.insert(
              id: 'e$i',
              category: 'build',
              title: 'TRACE',
              date: '2026-09-18',
              createdAt: at(9),
              updatedAt: at(9),
            ),
        ]),
      );
      await sync(phoneSync);
      await sync(tabletSync);
      expect(await tablet.allEntries(), hasLength(count));

      await phone.tombstoneEverything();
      await sync(phoneSync);
      await sync(tabletSync);

      expect(await tablet.allEntries(), isEmpty);
    },
  );

  test('a sync with nothing new pulls nothing', () async {
    await addEntry(phone, 'e1', at(9));
    await addProject(phone, 'p1', at(9));
    await sync(phoneSync);

    server.pulledRows = 0;
    await sync(phoneSync);

    expect(server.pulledRows, 0);
  });

  test('a successful sync clears the previous failure', () async {
    await phone.updateSyncState(error: 'No connection');

    await sync(phoneSync);

    expect((await phone.syncState())!.lastError, isNull);
  });

  group('a device clock running ahead', () {
    final serverTime = DateTime.utc(2026, 9, 19, 12);
    final dayAhead = serverTime.add(const Duration(days: 1));

    test('is clamped to within five minutes of the server', () async {
      server.clock = () => serverTime;
      await addEntry(phone, 'e1', dayAhead);

      await sync(phoneSync);

      final stored =
          DateTime.parse(server.rows('entries')['e1']!['updated_at'] as String);
      expect(stored, serverTime.add(const Duration(minutes: 5)));
      // The phone takes the clamped time back on the same sync's pull.
      expect((await phone.findEntry('e1'))!.updatedAt.toUtc(),
          serverTime.add(const Duration(minutes: 5)));
    });

    test('cannot outvote a later edit made with a correct clock', () async {
      server.clock = () => serverTime;
      await addEntry(phone, 'e1', dayAhead, title: 'Walk');
      await sync(phoneSync);
      await sync(tabletSync);

      // Ten minutes later, by the server's clock and the tablet's.
      final later = serverTime.add(const Duration(minutes: 10));
      server.clock = () => later;
      await retitle(tablet, 'e1', 'Long walk', later);
      await sync(tabletSync);
      await sync(phoneSync);

      expect(server.rows('entries')['e1']!['title'], 'Long walk');
      expect((await phone.findEntry('e1'))!.title, 'Long walk');
    });

    test('a server without server_now() still syncs, unclamped', () async {
      server.clock = () => null;
      await addEntry(phone, 'e1', dayAhead);

      await sync(phoneSync);

      expect(
        DateTime.parse(server.rows('entries')['e1']!['updated_at'] as String),
        dayAhead,
      );
    });
  });
}
