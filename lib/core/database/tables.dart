import 'package:drift/drift.dart';

/// Columns every syncable table carries.
///
/// `updatedAt` drives last-write-wins and is always written by the client —
/// never by a trigger — so it records when *you* made the edit, not when the row
/// reached a server. `deletedAt` is a tombstone: rows are never hard-deleted,
/// because a delete that cannot propagate is a delete that resurrects.
mixin SyncTail on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Local-only. Not sent to Postgres.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// Local-only. Not sent to Postgres.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Something the user actually did.
///
/// Duration and quantity are independent and both optional — an entry may use
/// one, the other, or neither. Nothing is forced into a time value.
class Entries extends Table with SyncTail {
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  /// The day this belongs to, as ISO `yyyy-MM-dd`.
  ///
  /// Stored as text rather than a timestamp so grouping never drifts across a
  /// timezone change, and so it maps directly onto Postgres `date`.
  TextColumn get date => text().withLength(min: 10, max: 10)();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationSecs => integer().nullable()();

  RealColumn get quantity => real().nullable()();

  /// minutes | hours | pages | km | sessions | items | custom
  TextColumn get quantityUnit => text().nullable()();

  TextColumn get projectId => text().nullable()();
  TextColumn get bookId => text().nullable()();

  /// JSON array of strings.
  TextColumn get tags => text().withDefault(const Constant('[]'))();
}

/// Something built over time. Aggregates BUILD entries.
class Projects extends Table with SyncTail {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// active | paused | done | archived
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Only set when the user has explicitly defined a target.
  ///
  /// Progress percentages are shown *only* when this exists. Without a target a
  /// percentage would be invented, and inventing one is exactly what the product
  /// brief forbids.
  IntColumn get targetSecs => integer().nullable()();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

class Books extends Table with SyncTail {
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  IntColumn get totalPages => integer().nullable()();

  /// want | reading | finished | abandoned
  TextColumn get status => text().withDefault(const Constant('reading'))();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
}

/// Lightweight reflection attached to a day, entry, project or book.
///
/// The ONE LINE on Today is simply a Note with `kind = one_line` and a `date` —
/// not a table of its own.
class Notes extends Table with SyncTail {
  TextColumn get body => text()();

  /// one_line | thought | quote | note
  TextColumn get kind => text().withDefault(const Constant('note'))();

  TextColumn get date => text().nullable()();
  TextColumn get entryId => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get bookId => text().nullable()();
}

/// Optional evidence that an entry happened. Never required.
class Proofs extends Table with SyncTail {
  TextColumn get entryId => text()();

  /// git | screenshot | note | link | file
  TextColumn get kind => text()();
  TextColumn get label => text().nullable()();
  TextColumn get uri => text().nullable()();
}

/// Single-row sync bookkeeping. Local only, never synced.
class SyncStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get lastPushAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
