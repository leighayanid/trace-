import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import 'project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);

final projectTimeProvider =
    StreamProvider.family<Duration, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).watchTime(id);
});

final projectSessionsProvider =
    StreamProvider.family<List<Entry>, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).watchSessions(id);
});

final projectByIdProvider =
    StreamProvider.family<Project?, String>((ref, id) {
  return ref
      .watch(databaseProvider)
      .watchProjects()
      .map((all) => all.where((p) => p.id == id).firstOrNull);
});
