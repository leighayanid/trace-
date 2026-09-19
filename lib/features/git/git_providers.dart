import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'github_client.dart';

/// The GitHub token, kept in the platform's secure storage and nowhere else.
/// Never logged, never synced — it is this device's key, not part of the record.
class GitHubTokenStore {
  const GitHubTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'trace.github_token';
  static const _loginKey = 'trace.github_login';

  Future<({String token, String login})?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final login = await _storage.read(key: _loginKey);
    return token == null || login == null ? null : (token: token, login: login);
  }

  Future<void> write(String token, String login) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _loginKey, value: login);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loginKey);
  }
}

final gitHubTokenStoreProvider = Provider<GitHubTokenStore>(
  (ref) => const GitHubTokenStore(),
);

/// Which GitHub account is connected, if any.
class GitHubAccount extends AsyncNotifier<({String token, String login})?> {
  @override
  Future<({String token, String login})?> build() =>
      ref.read(gitHubTokenStoreProvider).read();

  /// Checks [token] against GitHub before keeping it, so a mistyped token is
  /// caught here rather than on the next import. Throws [GitHubException].
  Future<void> connect(String token) async {
    final trimmed = token.trim();
    final client = GitHubClient(token: trimmed);
    try {
      final login = await client.login();
      await ref.read(gitHubTokenStoreProvider).write(trimmed, login);
      state = AsyncData((token: trimmed, login: login));
    } finally {
      client.close();
    }
  }

  Future<void> disconnect() async {
    await ref.read(gitHubTokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final gitHubAccountProvider =
    AsyncNotifierProvider<GitHubAccount, ({String token, String login})?>(
      GitHubAccount.new,
    );
