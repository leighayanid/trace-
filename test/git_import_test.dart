import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trace/core/database/database.dart';
import 'package:trace/features/git/commit_days.dart';
import 'package:trace/features/git/github_client.dart';
import 'package:trace/shared/models/category.dart';

/// GitHub commits become suggested BUILD entries — one per repo per day.
void main() {
  Map<String, dynamic> item(String repo, String message, String date) => {
        'repository': {'full_name': repo},
        'commit': {
          'message': message,
          'author': {'date': date},
        },
      };

  group('GitHubClient', () {
    test('asks for your commits since a day, with the token', () async {
      late http.Request seen;
      final client = GitHubClient(
        token: 'github_pat_x',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'items': [
                item('leigh/trace', 'Fix routing\n\nLonger body', '2026-09-18T10:00:00Z'),
              ],
            }),
            200,
          );
        }),
      );

      final commits = await client.commitsSince('leigh', DateTime(2026, 9, 5));

      expect(seen.url.path, '/search/commits');
      expect(seen.url.queryParameters['q'], 'author:leigh author-date:>=2026-09-05');
      expect(seen.headers['Authorization'], 'Bearer github_pat_x');
      expect(commits.single.repo, 'leigh/trace');
      expect(commits.single.repoName, 'trace');
      expect(commits.single.message, 'Fix routing');
    });

    test('follows full pages, and stops at a short one', () async {
      var calls = 0;
      final client = GitHubClient(
        token: 't',
        client: MockClient((req) async {
          calls++;
          final n = calls == 1 ? 100 : 7;
          return http.Response(
            jsonEncode({
              'items': [
                for (var i = 0; i < n; i++)
                  item('leigh/trace', 'c$i', '2026-09-18T10:00:00Z'),
              ],
            }),
            200,
          );
        }),
      );

      final commits = await client.commitsSince('leigh', DateTime(2026, 9, 5));
      expect(calls, 2);
      expect(commits, hasLength(107));
    });

    test('a refused token says so plainly', () async {
      final client = GitHubClient(
        token: 'bad',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      await expectLater(
        client.login(),
        throwsA(isA<GitHubException>()
            .having((e) => e.message, 'message', contains('refused the token'))),
      );
    });
  });

  group('groupCommits', () {
    final t = DateTime.utc(2026, 9, 1);
    final pds = Project(
      id: 'p1',
      name: 'PDS Express',
      status: 'active',
      createdAt: t,
      updatedAt: t,
      dirty: false,
    );

    GitCommit commit(String repo, String message, DateTime at) =>
        GitCommit(repo: repo, message: message, at: at);

    test('one suggestion per repository per day, newest day first', () {
      final days = groupCommits([
        commit('leigh/trace', 'a', DateTime(2026, 9, 17, 9)),
        commit('leigh/trace', 'b', DateTime(2026, 9, 17, 15)),
        commit('leigh/trace', 'c', DateTime(2026, 9, 18, 10)),
        commit('leigh/nuxt-cli', 'd', DateTime(2026, 9, 17, 11)),
      ]);

      expect([for (final d in days) (d.repo, d.date.day)], [
        ('trace', 18),
        ('nuxt-cli', 17),
        ('trace', 17),
      ]);
      // Newest commit first within a day.
      expect(days[2].messages, ['b', 'a']);
    });

    test('a repository joins the project with the same name', () {
      final days = groupCommits(
        [commit('leigh/pds-express', 'Fix fares', DateTime(2026, 9, 18))],
        projects: [pds],
      );
      final draft = days.single.toDraft();
      expect(draft.projectId, 'p1');
      expect(draft.title, 'PDS Express');
      expect(draft.category, Category.build);
      expect(draft.duration, isNull);
      expect(draft.date, DateTime(2026, 9, 18));
    });

    test('a day already recorded is offered but marked', () {
      final existing = Entry(
        id: 'e1',
        category: 'build',
        title: 'PDS Express',
        date: '2026-09-18',
        projectId: 'p1',
        tags: '[]',
        createdAt: t,
        updatedAt: t,
        dirty: false,
      );
      final days = groupCommits(
        [
          commit('leigh/pds-express', 'x', DateTime(2026, 9, 18)),
          commit('leigh/pds-express', 'y', DateTime(2026, 9, 17)),
        ],
        projects: [pds],
        existing: [existing],
      );
      expect([for (final d in days) d.logged], [true, false]);
    });

    test('the note lists the first five messages and counts the rest', () {
      final days = groupCommits([
        for (var i = 1; i <= 7; i++)
          commit('leigh/trace', 'm$i', DateTime(2026, 9, 18, i)),
      ]);
      expect(
        days.single.toDraft().description,
        '7 commits: m7 · m6 · m5 · m4 · m3 · +2 more',
      );
    });
  });
}
