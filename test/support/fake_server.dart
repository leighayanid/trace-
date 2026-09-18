import 'package:trace/core/sync/data_api_client.dart';

/// An in-memory stand-in for the Neon Data API that keeps the rules of
/// migration 002: every write is stamped with the next `server_seq`, and an
/// older `updated_at` never overwrites a newer one — the stored row is
/// re-stamped instead, so it goes back out to every device.
class FakeServer implements DataApiClient {
  final _tables = <String, Map<String, Map<String, dynamic>>>{};
  var _seq = 0;

  /// Rows handed out by [pull], across all tables.
  var pulledRows = 0;

  Map<String, Map<String, dynamic>> rows(String table) =>
      _tables.putIfAbsent(table, () => {});

  void _write(String table, Map<String, dynamic> row) {
    final stored = rows(table);
    final existing = stored[row['id']];
    final stale =
        existing != null &&
        DateTime.parse(
          row['updated_at'] as String,
        ).isBefore(DateTime.parse(existing['updated_at'] as String));
    stored[row['id'] as String] = {
      ...(stale ? existing : row),
      'server_seq': ++_seq,
    };
  }

  @override
  Future<void> push({
    required String table,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      _write(table, row);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required int? afterSeq,
    int limit = DataApiClient.pageSize,
  }) async {
    final page =
        rows(table).values
            .where(
              (r) => afterSeq == null || (r['server_seq'] as int) > afterSeq,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['server_seq'] as int).compareTo(b['server_seq'] as int),
          );
    final out = [for (final r in page.take(limit)) Map.of(r)];
    pulledRows += out.length;
    return out;
  }
}
