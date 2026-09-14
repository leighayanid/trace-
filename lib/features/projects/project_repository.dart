import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';

enum ProjectStatus {
  active('active', 'Active'),
  paused('paused', 'Paused'),
  done('done', 'Done'),
  archived('archived', 'Archived');

  const ProjectStatus(this.key, this.label);
  final String key;
  final String label;

  static ProjectStatus parse(String v) => ProjectStatus.values
      .firstWhere((s) => s.key == v, orElse: () => ProjectStatus.active);
}

class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Project>> watchAll() => _db.watchProjects();

  /// Derived from entries, never stored on the project row.
  Stream<Duration> watchTime(String id) => _db.watchProjectTime(id);

  Stream<List<Entry>> watchSessions(String id) =>
      _db.watchEntriesForProject(id);

  Future<String> create({
    required String name,
    String? description,
    Duration? target,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v7();
    await _db.upsertProject(
      ProjectsCompanion.insert(
        id: id,
        name: name.trim(),
        description: Value(description?.trim()),
        targetSecs: Value(target?.inSeconds),
        startedAt: Value(now),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> update({
    required String id,
    String? name,
    String? description,
    ProjectStatus? status,
    Duration? target,
    bool clearTarget = false,
  }) {
    return _db.updateProject(
      ProjectsCompanion(
        id: Value(id),
        name: name == null ? const Value.absent() : Value(name.trim()),
        description:
            description == null ? const Value.absent() : Value(description),
        status: status == null ? const Value.absent() : Value(status.key),
        targetSecs: clearTarget
            ? const Value(null)
            : (target == null ? const Value.absent() : Value(target.inSeconds)),
        updatedAt: Value(DateTime.now().toUtc()),
        dirty: const Value(true),
      ),
    );
  }
}
