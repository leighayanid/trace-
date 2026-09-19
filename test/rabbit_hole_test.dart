import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/features/entries/entry_draft.dart';
import 'package:trace/features/entries/entry_repository.dart';
import 'package:trace/features/notes/note_repository.dart';
import 'package:trace/shared/models/category.dart';

/// Rabbit holes: EXPLORE entries that led on from each other.
void main() {
  late AppDatabase db;
  late EntryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });
  tearDown(() => db.close());

  Future<String> explore(String title, {String? from}) => repo.create(
        EntryDraft(category: Category.explore, title: title, parentId: from),
      );

  Future<List<String>> above(String id) async =>
      [for (final e in await db.ancestorsOf(id)) e.title];

  test('a chain reads from where it started down to the entry', () async {
    final workers = await explore('Cloudflare Workers');
    final dobj = await explore('Durable Objects', from: workers);
    final sqlite = await explore('SQLite', from: dobj);
    final dist = await explore('Distributed systems', from: sqlite);

    expect(await above(dist), ['Cloudflare Workers', 'Durable Objects', 'SQLite']);
    expect(await above(workers), isEmpty);
  });

  test('an entry can lead to more than one thing', () async {
    final root = await explore('Durable Objects');
    await explore('SQLite', from: root);
    await explore('Alarms', from: root);

    final children = await db.watchChildren(root).first;
    // Same second, so the order between them is not asserted.
    expect([for (final e in children) e.title],
        unorderedEquals(['SQLite', 'Alarms']));
  });

  test('a link that would loop back is dropped', () async {
    final a = await explore('A');
    final b = await explore('B', from: a);

    // Make A lead on from B, its own child.
    await repo.save(
      a,
      EntryDraft(category: Category.explore, title: 'A', parentId: b),
    );

    expect((await repo.find(a))!.parentId, isNull);
    expect(await above(b), ['A']);
  });

  test('only EXPLORE entries join a rabbit hole', () async {
    final root = await explore('Durable Objects');
    final id = await repo.create(
      EntryDraft(category: Category.build, title: 'TRACE', parentId: root),
    );
    expect((await repo.find(id))!.parentId, isNull);
  });

  test('a deleted step ends the chain there', () async {
    final a = await explore('A');
    final b = await explore('B', from: a);
    final c = await explore('C', from: b);

    await repo.delete(b);

    expect(await above(c), isEmpty);
    expect(await db.watchChildren(b).first, hasLength(1));
  });

  test('recent EXPLORE entries, never the entry itself', () async {
    final a = await explore('A');
    await repo.create(const EntryDraft(category: Category.life, title: 'Walk'));
    final b = await explore('B');

    final options = await db.recentExplore(excluding: a);
    expect([for (final e in options) e.id], [b]);
  });

  test('a quote keeps its page; a thought has none', () async {
    final notes = NoteRepository(db);
    await notes.addBookNote('b1', 'Small wins.', kind: 'quote', page: 42);
    await notes.addBookNote('b1', 'This matters.');

    final all = await db.allNotes();
    final quote = all.firstWhere((n) => n.kind == 'quote');
    final thought = all.firstWhere((n) => n.kind == 'thought');
    expect(quote.page, 42);
    expect(thought.page, isNull);
  });
}
