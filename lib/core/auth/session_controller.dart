import 'dart:async';
import 'dart:convert';

/// Holds the session, and hands out a valid JWT on demand.
///
/// The single-flight guard is the point of this class. A sync push can ask for
/// a token from a dozen queued rows within the same millisecond; without it,
/// each would start its own refresh, and the auth service would see a burst of
/// identical requests for no reason.
class SessionController {
  SessionController({
    required Future<String> Function(String sessionToken) fetchJwt,
    required Future<String?> Function() readSession,
  })  : _fetchJwt = fetchJwt,
        _readSession = readSession;

  final Future<String> Function(String sessionToken) _fetchJwt;
  final Future<String?> Function() _readSession;

  String? _jwt;
  DateTime? _expiry;
  Future<String>? _inFlight;

  /// Refresh this far ahead of expiry, so a request never races the clock.
  static const _skew = Duration(minutes: 2);

  bool get hasValidJwt {
    final expiry = _expiry;
    return _jwt != null &&
        expiry != null &&
        DateTime.now().toUtc().isBefore(expiry.subtract(_skew));
  }

  /// Returns a JWT, refreshing only when the cached one is near expiry.
  ///
  /// Concurrent callers share one refresh.
  Future<String> jwt() {
    if (hasValidJwt) return Future.value(_jwt!);
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String> _refresh() async {
    final session = await _readSession();
    if (session == null || session.isEmpty) {
      throw StateError('Not signed in');
    }
    final token = await _fetchJwt(session);
    _jwt = token;
    _expiry = expiryOf(token);
    return token;
  }

  /// Drops the cached JWT. Called on sign-out and on a 401 from the Data API.
  void invalidate() {
    _jwt = null;
    _expiry = null;
  }

  /// Reads `exp` out of a JWT payload without verifying the signature.
  ///
  /// Verification is the server's job — this only decides *when to refresh*, so
  /// a forged token would simply be refreshed at the wrong moment and then
  /// rejected by the Data API anyway.
  ///
  /// Returns null when the token is unreadable; callers treat that as
  /// "expires immediately" and refresh, which is the safe direction to fail.
  static DateTime? expiryOf(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;

      final normalised = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalised)));
      if (payload is! Map) return null;

      final exp = payload['exp'];
      if (exp is! int) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}
