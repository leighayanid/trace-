import 'package:postgrest/postgrest.dart';

import '../auth/session_controller.dart';

/// Thin wrapper over the Neon Data API (PostgREST).
///
/// Its whole job is to make sure every request carries a fresh JWT, and to
/// recover once from an expired one.
class DataApiClient {
  DataApiClient({
    required String dataApiUrl,
    required SessionController session,
    PostgrestClient? client,
  })  : _session = session,
        _client = client ?? PostgrestClient(dataApiUrl);

  final PostgrestClient _client;

  final SessionController _session;

  /// Rows per page. PostgREST caps responses, and a personal history is small
  /// enough that 500 is one or two round trips.
  static const pageSize = 500;

  Future<void> _authorise() async {
    final jwt = await _session.jwt();
    // The headers map is mutable, so the token can be swapped without
    // rebuilding the client and losing its retry configuration.
    _client.headers['Authorization'] = 'Bearer $jwt';
  }

  /// Runs [action] with a valid token, retrying once if the server rejects it.
  ///
  /// A JWT can expire between the refresh check and the request landing. One
  /// retry turns that race into a non-event; retrying further would just mask a
  /// genuine credential problem.
  Future<T> _guarded<T>(Future<T> Function() action) async {
    await _authorise();
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code != '401' && e.code != 'PGRST301') rethrow;
      _session.invalidate();
      await _authorise();
      return await action();
    }
  }

  /// Rows changed strictly after [cursor], oldest first.
  ///
  /// Ordering by `updated_at` ascending is what makes the cursor resumable: a
  /// pull can stop at any point and continue from the last row it saw.
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required DateTime? cursor,
    int limit = pageSize,
  }) {
    return _guarded(() async {
      var query = _client.from(table).select();
      if (cursor != null) {
        query = query.gt('updated_at', cursor.toUtc().toIso8601String());
      }
      final rows = await query.order('updated_at', ascending: true).limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    });
  }

  /// Upserts a batch, keyed on the primary key.
  ///
  /// `user_id` is deliberately absent from the payload: the column defaults to
  /// `auth.user_id()`, so the server decides ownership from the token and a
  /// client cannot claim to be someone else.
  Future<void> push({
    required String table,
    required List<Map<String, dynamic>> rows,
  }) {
    if (rows.isEmpty) return Future.value();
    return _guarded(
      () => _client.from(table).upsert(rows, onConflict: 'id'),
    );
  }

  // Deliberately no serverTime(): the obvious implementation would return
  // DateTime.now(), which is the *client* clock and therefore useless for
  // clamping client skew. Conflict.clampToServer stays tested and unwired until
  // there is a real server clock to read — PostgREST does not surface the
  // response `Date` header through this package. See PLAN.md §5.
}
