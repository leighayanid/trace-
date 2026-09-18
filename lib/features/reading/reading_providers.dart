import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import 'book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(databaseProvider)),
);

final bookByIdProvider = StreamProvider.family<Book?, String>((ref, id) {
  return ref
      .watch(databaseProvider)
      .watchBooks()
      .map((all) => all.where((b) => b.id == id).firstOrNull);
});

final bookSessionsProvider =
    StreamProvider.family<List<Entry>, String>((ref, id) {
  return ref.watch(bookRepositoryProvider).watchSessions(id);
});

/// Pages logged per book id. Every bookmark on screen is read from this.
final pagesReadProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(databaseProvider).watchPagesRead(),
);
