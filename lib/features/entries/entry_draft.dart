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
  });

  /// What the parser proposed. The parser suggests; the form decides.
  factory EntryDraft.fromParsed(ParsedEntry p) => EntryDraft(
        category: p.category,
        title: p.title.isEmpty ? p.raw : p.title,
        duration: p.duration,
        quantity: p.quantity,
        quantityUnit: p.quantityUnit,
        projectId: p.projectId,
        bookId: p.bookId,
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
      );

  final Category category;
  final String title;
  final String? description;
  final Duration? duration;
  final double? quantity;
  final String? quantityUnit;
  final String? projectId;
  final String? bookId;
}
