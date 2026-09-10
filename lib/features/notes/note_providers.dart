import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import 'note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(databaseProvider)),
);

final bookNotesProvider =
    StreamProvider.family<List<Note>, String>((ref, bookId) {
  return ref.watch(databaseProvider).watchNotesForBook(bookId);
});
