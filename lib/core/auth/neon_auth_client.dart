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
/// ## Two tokens, and they are not interchangeable
///
/// This is the part most likely to cost a day if it is misread:
///
/// - the **session token** is opaque and long-lived. It is returned by sign-in
///   in the `set-auth-token` response header and talks only to the auth
///   service. It belongs in secure storage.
/// - the **JWT** is short-lived, fetched from `/api/auth/token` using the
///   session token, and is the only thing the Data API will accept. It belongs
///   in memory.
///
/// ## Unverified
///
/// Neon controls the plugin configuration of its managed Better Auth, not us.
/// Whether the bearer plugin is enabled — that is, whether `set-auth-token`
/// actually comes back on sign-in — could not be confirmed without a live
/// project. [signIn] therefore falls back to reading the token from the
/// response body, and throws a descriptive error if neither is present, rather
/// than returning something plausible and wrong.
///
/// Verify with three curls before trusting this in anger; see PLAN.md §5.
class NeonAuthClient {
  NeonAuthClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// e.g. `https://PROJECT.auth.neon.tech`
  final String baseUrl;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$baseUrl/api/auth$path');

  /// Signs in and returns the **session** token.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _post('/sign-in/email', {
      'email': email,
      'password': password,
    });
    return _extractSessionToken(res);
  }

  /// Creates the account and returns the **session** token.
  ///
  /// TRACE has one user, so this runs once, ever. It exists so the account can
  /// be made from the app rather than out of band.
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
    return _extractSessionToken(res);
  }

  /// Exchanges a session token for the short-lived JWT the Data API validates.
  Future<String> fetchJwt(String sessionToken) async {
    final res = await _http.get(
      _uri('/token'),
      headers: {'Authorization': 'Bearer $sessionToken'},
    ).timeout(_timeout);

    if (res.statusCode >= 400) {
      throw AuthException(
        'Token exchange rejected',
        statusCode: res.statusCode,
      );
    }

    final body = _decode(res.body);
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(
        'Token exchange returned no token. If the JWT plugin is not enabled on '
        'this Neon project, the Data API cannot be reached with a session '
        'token alone.',
      );
    }
    return token;
  }

  Future<void> signOut(String sessionToken) async {
    try {
      await _http.post(
        _uri('/sign-out'),
        headers: {'Authorization': 'Bearer $sessionToken'},
      ).timeout(_timeout);
    } catch (_) {
      // A failed sign-out must never strand the user in a signed-in UI. The
      // local token is cleared by the caller regardless.
    }
  }

  Future<http.Response> _post(String path, Map<String, Object?> body) async {
    final res = await _http
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
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

  /// Prefers the bearer-plugin header, falls back to the body.
  static String _extractSessionToken(http.Response res) {
    final header = res.headers['set-auth-token'];
    if (header != null && header.isNotEmpty) return header;

    final body = _decode(res.body);
    for (final key in const ['token', 'sessionToken']) {
      final v = body[key];
      if (v is String && v.isNotEmpty) return v;
    }
    final session = body['session'];
    if (session is Map && session['token'] is String) {
      return session['token'] as String;
    }

    throw const AuthException(
      'Sign-in succeeded but returned no session token. This usually means the '
      'bearer plugin is not enabled on this Neon project, and the session is '
      'being issued as a cookie instead — which needs a cookie jar rather than '
      'a bearer header.',
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
