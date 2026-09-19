import '../../core/database/database.dart';
import '../../shared/models/category.dart';
import '../entries/entry_draft.dart';
import '../entries/entry_repository.dart';
import 'github_client.dart';

/// A day's commits to one repository — one suggested BUILD entry.
class CommitDay {
  const CommitDay({
    required this.repo,
    required this.date,
    required this.messages,
    this.project,
    this.logged = false,
  });

  final String repo;

  /// Local midnight.
  final DateTime date;

  /// First lines, newest first.
  final List<String> messages;

  /// The project whose name matches the repository, if any.
  final Project? project;

  /// Something is already recorded for this repository on this day. Offered,
  /// but not ticked.
  final bool logged;

  String get title => project?.name ?? repo;

  /// No duration: a commit says what was done, not how long it took, and an
  /// invented number would be worse than none. The messages go in the note,
  /// which is what makes the entry searchable later.
  EntryDraft toDraft() {
    final shown = messages.take(5).join(' · ');
    final more = messages.length > 5 ? ' · +${messages.length - 5} more' : '';
    final count = messages.length == 1
        ? '1 commit'
        : '${messages.length} commits';
    return EntryDraft(
      category: Category.build,
      title: title,
      description: '$count: $shown$more',
      projectId: project?.id,
      date: date,
    );
  }
}

/// Letters and digits only, lower case: "pds-express" and "PDS Express" meet.
String _squash(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// Groups [commits] into one suggestion per repository per day, newest day
/// first, matched to [projects] by name and checked against [existing]
/// entries so a day already recorded is not added twice.
List<CommitDay> groupCommits(
  List<GitCommit> commits, {
  List<Project> projects = const [],
  List<Entry> existing = const [],
}) {
  final byName = {for (final p in projects) _squash(p.name): p};

  final groups = <(String, String), List<GitCommit>>{};
  for (final c in commits) {
    groups.putIfAbsent((c.repoName, dayKey(c.at)), () => []).add(c);
  }

  final days = <CommitDay>[];
  for (final MapEntry(key: (repo, day), value: list) in groups.entries) {
    final project = byName[_squash(repo)];
    final logged = existing.any(
      (e) =>
          e.date == day &&
          e.deletedAt == null &&
          e.category == Category.build.name &&
          (project != null
              ? e.projectId == project.id
              : _squash(e.title) == _squash(repo)),
    );
    list.sort((a, b) => b.at.compareTo(a.at));
    days.add(
      CommitDay(
        repo: repo,
        date: DateTime.parse(day),
        messages: [for (final c in list) c.message],
        project: project,
        logged: logged,
      ),
    );
  }
  days.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.repo.compareTo(b.repo);
  });
  return days;
}
