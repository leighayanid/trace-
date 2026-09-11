import 'dart:convert';

import 'package:http/http.dart' as http;

/// Raised for any auth failure. Carries no token material, ever.
class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AuthException($statusCode): $message';
}

/// A hand-rolled client for Neon's Managed Better Auth.
///
/// There is no Dart SDK, so this is code we own. It speaks the stock Better
/// Auth REST surface, which Neon runs as a managed service.
///
/// ## Two credentials, and they are not interchangeable
///
/// - the **session** is a cookie, `__Secure-neon-auth.session_token`, set by
///   sign-in and long-lived. It talks only to the auth service and belongs in
///   secure storage. It is kept as the literal `name=value` pair and replayed
///   in a `Cookie` header — the browser's job, done by hand.
/// - the **JWT** is short-lived, fetched from `/token` with that cookie, and is
///   the only thing the Data API will accept. It belongs in memory.
///
/// ## Verified against a live project (2026-09-11)
///
/// - Neon's managed Better Auth has **no bearer plugin**: a session token sent
///   as `Authorization: Bearer` is refused with 401, and sign-in sets no
///   `set-auth-token` header. The `token` field in the sign-in body is the raw
///   session id, which is useless without the cookie's signature. The cookie is
///   the only session credential that works.
/// - Sign-up and sign-in are refused with `400 MISSING_ORIGIN` unless an
///   `Origin` header names a trusted domain. `GET /token` needs none.
///
/// `tool/neon_check.sh` re-runs these checks.
class NeonAuthClient {
  NeonAuthClient({
    required this.baseUrl,
    required this.origin,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The Auth URL from the Neon Console, which already ends in the auth path:
  /// `https://ep-XXX.neonauth.REGION.aws.neon.tech/neondb/auth`.
  final String baseUrl;

  /// Sent as `Origin` on every POST, which Better Auth requires.
  ///
  /// A native app has no real origin, so this is a label the server checks
  /// against its trusted domains. Configured as `NEON_AUTH_ORIGIN`; see
  /// `TraceConfig.authOrigin`.
  final String origin;

  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  /// Matches the session cookie by suffix rather than exact name, so a change
  /// of prefix on Neon's side does not break sign-in. Companions that share the
  /// prefix (`…session_data`) do not end in `session_token` and are skipped, as
  /// is a cleared cookie with an empty value.
  static final _sessionCookie =
      RegExp(r'(?:^|[\s,;])([\w.-]*session_token)=([^;,\s]+)');

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Signs in and returns the **session** cookie, as `name=value`.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _post('/sign-in/email', {
      'email': email,
      'password': password,
    });
    return _extractSession(res);
  }

  /// Creates the account and returns the **session** cookie, as `name=value`.
  ///
  /// TRACE has one user, so this runs once, ever, and the app has no screen for
  /// it — `tool/neon_check.sh` makes the account.
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _post('/sign-up/email', {
      'email': email,
      'password': password,
      'name': name,
    });
    return _extractSession(res);
  }

  /// Exchanges the session cookie for the short-lived JWT the Data API
  /// validates.
  Future<String> fetchJwt(String session) async {
    final res = await _http.get(
      _uri('/token'),
      headers: {'Cookie': session},
    ).timeout(_timeout);

    if (res.statusCode >= 400) {
      throw AuthException(
        res.statusCode == 401
            ? 'Session expired — sign in again'
            : 'Token exchange rejected',
        statusCode: res.statusCode,
      );
    }

    final body = _decode(res.body);
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException('Token exchange returned no token');
    }
    return token;
  }

  Future<void> signOut(String session) async {
    try {
      await _http.post(
        _uri('/sign-out'),
        headers: {'Cookie': session, 'Origin': origin},
      ).timeout(_timeout);
    } catch (_) {
      // A failed sign-out must never strand the user in a signed-in UI. The
      // local session is cleared by the caller regardless.
    }
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    final res = await _http
        .post(
          _uri(path),
          headers: {'Content-Type': 'application/json', 'Origin': origin},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (res.statusCode >= 400) {
      throw AuthException(
        _messageFor(res),
        statusCode: res.statusCode,
      );
    }
    return res;
  }

  /// Pulls the session cookie out of `Set-Cookie`.
  ///
  /// `package:http` folds repeated `Set-Cookie` headers into one
  /// comma-separated string, and `Expires=Wed, 21 Oct …` has commas of its
  /// own — hence a pattern that anchors on the cookie name, not a split.
  static String _extractSession(http.Response res) {
    final header = res.headers['set-cookie'] ?? '';
    for (final m in _sessionCookie.allMatches(header)) {
      final value = m.group(2)!;
      if (value.isNotEmpty) return '${m.group(1)}=$value';
    }
    throw const AuthException(
      'Sign-in succeeded but set no session cookie. Check that the Auth URL '
      'is the one from the Neon Console.',
    );
  }

  /// Surfaces the server's own message where there is one, never the raw body,
  /// which can contain token material.
  static String _messageFor(http.Response res) {
    try {
      final body = _decode(res.body);
      final message = body['message'] ?? body['error'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      // fall through
    }
    return switch (res.statusCode) {
      401 || 403 => 'Email or password not accepted',
      404 => 'Auth endpoint not found — check NEON_AUTH_BASE_URL',
      429 => 'Too many attempts; try again shortly',
      _ => 'Sign-in failed',
    };
  }

  static Map<String, Object?> _decode(String body) {
    if (body.isEmpty) return const {};
    final decoded = jsonDecode(body);
    return decoded is Map<String, Object?> ? decoded : const {};
  }

  void dispose() => _http.close();
}
