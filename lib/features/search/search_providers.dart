import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';

/// The words of a query, each of which must appear. Blank for a blank query.
List<String> searchWords(String query) =>
    query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// How many results a search shows. The span line still counts them all.
const searchLimit = 200;

final searchEntriesProvider = StreamProvider.autoDispose
    .family<List<Entry>, String>((ref, query) {
      return ref
          .watch(databaseProvider)
          .watchEntriesMatching(searchWords(query), limit: searchLimit);
    });

final searchNotesProvider = StreamProvider.autoDispose
    .family<List<Note>, String>((ref, query) {
      return ref.watch(databaseProvider).watchNotesMatching(searchWords(query));
    });

/// First day, latest day and count of every matching entry.
final searchSpanProvider = StreamProvider.autoDispose
    .family<({String? first, String? last, int count}), String>((ref, query) {
      return ref.watch(databaseProvider).watchMatchSpan(searchWords(query));
    });
