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

  /// Rows the server stamped strictly after [afterSeq], in server order.
  ///
  /// `server_seq` is assigned by Postgres on every write (migration 002), so it
  /// is unique and follows arrival at the server. That is what makes the
  /// cursor resumable, and what stops a late-syncing device's rows, or a page
  /// of rows sharing one timestamp, from falling behind it.
  Future<List<Map<String, dynamic>>> pull({
    required String table,
    required int? afterSeq,
    int limit = pageSize,
  }) {
    return _guarded(() async {
      var query = _client.from(table).select();
      if (afterSeq != null) query = query.gt('server_seq', afterSeq);
      final rows =
          await query.order('server_seq', ascending: true).limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    });
  }

  /// Upserts a batch, keyed on the primary key.
  ///
  /// The server refuses to let an older `updated_at` overwrite a newer one
  /// (migration 002). A refused row is re-stamped rather than dropped, so the
  /// pull that follows brings the winning version back to this device.
  ///
  /// `user_id` is deliberately absent from the payload: the column defaults to
  /// `auth.uid()`, so the server decides ownership from the token and a
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

  /// The server's clock, from `server_now()` (migration 005).
  ///
  /// Null when the function does not exist yet, so a server that has not had
  /// 005 applied still syncs — only without skew clamping. Any other failure
  /// is a real one and propagates. The client clock is never substituted: it
  /// is the very thing being checked.
  Future<DateTime?> serverNow() {
    return _guarded(() async {
      try {
        final now = await _client.rpc<String>('server_now');
        return DateTime.parse(now).toUtc();
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST202') return null;
        rethrow;
      }
    });
  }
}
