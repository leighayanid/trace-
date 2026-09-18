import '../../core/database/database.dart';
import '../../core/parser/entry_parser.dart';
import '../../shared/models/category.dart';

/// Everything the entry form edits, as one value.
///
/// Saving a draft writes every field, so a field set to null here is cleared on
/// the row — which is how a duration is removed or a project unlinked. A
/// "null means unchanged" edit cannot express either.
class EntryDraft {
  const EntryDraft({
    required this.category,
    required this.title,
    this.description,
    this.duration,
    this.quantity,
    this.quantityUnit,
    this.projectId,
    this.bookId,
    this.date,
  });

  /// What the parser proposed. The parser suggests; the form decides.
  ///
  /// The day is the one the sentence named ("yesterday"), resolved against
  /// [today]; failing that [day], the day the user was looking at; failing
  /// that, null — today, whenever it is saved.
  factory EntryDraft.fromParsed(
    ParsedEntry p, {
    required DateTime today,
    DateTime? day,
  }) =>
      EntryDraft(
        category: p.category,
        title: p.title.isEmpty ? p.raw : p.title,
        duration: p.duration,
        quantity: p.quantity,
        quantityUnit: p.quantityUnit,
        projectId: p.projectId,
        bookId: p.bookId,
        date: p.day?.resolve(today) ?? day,
      );

  factory EntryDraft.fromEntry(Entry e) => EntryDraft(
        category: Category.tryParse(e.category) ?? Category.build,
        title: e.title,
        description: e.description,
        duration: e.durationSecs == null
            ? null
            : Duration(seconds: e.durationSecs!),
        quantity: e.quantity,
        quantityUnit: e.quantityUnit,
        projectId: e.projectId,
        bookId: e.bookId,
        date: DateTime.parse(e.date),
      );

  final Category category;
  final String title;
  final String? description;
  final Duration? duration;
  final double? quantity;
  final String? quantityUnit;
  final String? projectId;
  final String? bookId;

  /// The day it belongs to, as local midnight. Null means today.
  final DateTime? date;
}
