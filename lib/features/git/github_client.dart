import 'dart:convert';

import 'package:http/http.dart' as http;

/// One commit, reduced to what an entry can use.
class GitCommit {
  const GitCommit({
    required this.repo,
    required this.message,
    required this.at,
  });

  /// `owner/name`.
  final String repo;

  /// The first line of the message.
  final String message;

  /// When it was authored, in local time.
  final DateTime at;

  String get repoName => repo.split('/').last;
}

class GitHubException implements Exception {
  const GitHubException(this.message, {this.statusCode});

  /// Fit to show as it is.
  final String message;
  final int? statusCode;

  @override
  String toString() => 'GitHubException($statusCode): $message';
}

/// Reads your own commits from GitHub, and nothing else.
///
/// Only called when you open Import commits — TRACE never polls, and nothing it
/// fetches is kept except the entries you choose to add.
class GitHubClient {
  GitHubClient({required String token, http.Client? client})
    : _token = token,
      _http = client ?? http.Client();

  final String _token;
  final http.Client _http;

  static final _base = Uri.parse('https://api.github.com');

  /// The search API returns at most 100 a page; three pages is two weeks of a
  /// busy stretch.
  static const _pages = 3;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final http.Response res;
    try {
      res = await _http
          .get(
            _base.replace(path: path, queryParameters: query),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw const GitHubException('No connection to GitHub.');
    }
    switch (res.statusCode) {
      case 200:
        return jsonDecode(res.body) as Map<String, dynamic>;
      case 401:
        throw const GitHubException(
          'GitHub refused the token. It may have expired — paste a new one.',
          statusCode: 401,
        );
      case 403 || 429:
        throw GitHubException(
          'GitHub is rate-limiting requests. Try again in a minute.',
          statusCode: res.statusCode,
        );
      default:
        throw GitHubException(
          'GitHub answered ${res.statusCode}.',
          statusCode: res.statusCode,
        );
    }
  }

  /// The account the token belongs to. Also how a token is checked.
  Future<String> login() async => (await _get('/user'))['login'] as String;

  /// Your commits authored on or after [since], newest first.
  ///
  /// Uses commit search, which covers each repository's default branch — work
  /// still on a feature branch appears once it is merged.
  Future<List<GitCommit>> commitsSince(String login, DateTime since) async {
    final day = '${since.year}-${_two(since.month)}-${_two(since.day)}';
    final commits = <GitCommit>[];
    for (var page = 1; page <= _pages; page++) {
      final body = await _get('/search/commits', {
        'q': 'author:$login author-date:>=$day',
        'sort': 'author-date',
        'order': 'desc',
        'per_page': '100',
        'page': '$page',
      });
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      for (final item in items) {
        final commit = item['commit'] as Map<String, dynamic>;
        final author = commit['author'] as Map<String, dynamic>;
        commits.add(
          GitCommit(
            repo:
                (item['repository'] as Map<String, dynamic>)['full_name']
                    as String,
            message: (commit['message'] as String).split('\n').first.trim(),
            at: DateTime.parse(author['date'] as String).toLocal(),
          ),
        );
      }
      if (items.length < 100) break;
    }
    return commits;
  }

  void close() => _http.close();

  static String _two(int n) => n.toString().padLeft(2, '0');
}
