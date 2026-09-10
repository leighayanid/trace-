import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Better Auth session token.
///
/// Two rules, neither optional because this layer is hand-rolled: never log a
/// token, and never persist one outside secure storage.
///
/// Only the *session* token is stored. The JWT the Data API validates is
/// short-lived and lives in memory only — writing it to disk would mean keeping
/// a second credential with none of the benefit.
class TokenStore {
  const TokenStore([this._storage = const FlutterSecureStorage(
    // Android needs no options in v11: storage is KeyStore-backed AES/GCM by
    // default, which is why `encryptedSharedPreferences` no longer exists.
    // iOS uses first_unlock so a background sync can read the token without the
    // user having unlocked the device this session.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  )]);

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'trace.session_token';

  Future<String?> readSession() => _storage.read(key: _sessionKey);

  Future<void> writeSession(String token) =>
      _storage.write(key: _sessionKey, value: token);

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
