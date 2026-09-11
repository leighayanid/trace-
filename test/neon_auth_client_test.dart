import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trace/core/auth/neon_auth_client.dart';

/// The auth wire format, as observed against a live Neon project: the session
/// is a cookie, POSTs need an Origin, and bearer headers are refused.
void main() {
  const base = 'https://ep-test.neonauth.ap-southeast-1.aws.neon.tech/neondb/auth';

  // What package:http hands back for two Set-Cookie headers: folded into one
  // string, with the Expires date contributing a comma of its own.
  const setCookie = '__Secure-neon-auth.session_data=cache; Path=/; Secure, '
      '__Secure-neon-auth.session_token=abc123.sig%2Bx%3D; Max-Age=604800; '
      'Path=/; Expires=Fri, 18 Sep 2026 10:00:00 GMT; HttpOnly; Secure; '
      'SameSite=None';

  test('sign-in posts to the base URL with an Origin, and keeps the cookie',
      () async {
    late http.Request sent;
    final client = NeonAuthClient(
      baseUrl: base,
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response('{"token":"raw-id","user":{}}', 200,
            headers: {'set-cookie': setCookie});
      }),
    );

    final session = await client.signIn(email: 'a@b.c', password: 'pw');

    expect(sent.url.toString(), '$base/sign-in/email');
    expect(sent.headers['Origin'], NeonAuthClient.defaultOrigin);
    expect(jsonDecode(sent.body), {'email': 'a@b.c', 'password': 'pw'});
    // The signed cookie, not the raw `token` from the body.
    expect(session, '__Secure-neon-auth.session_token=abc123.sig%2Bx%3D');
  });

  test('sign-in without a session cookie fails loudly', () async {
    final client = NeonAuthClient(
      baseUrl: base,
      httpClient: MockClient(
          (_) async => http.Response('{"token":"raw-id"}', 200)),
    );

    expect(
      client.signIn(email: 'a@b.c', password: 'pw'),
      throwsA(isA<AuthException>()),
    );
  });

  test("the server's own error message reaches the user", () async {
    final client = NeonAuthClient(
      baseUrl: base,
      httpClient: MockClient((_) async => http.Response(
          '{"code":"INVALID_EMAIL_OR_PASSWORD",'
          '"message":"Invalid email or password"}',
          401)),
    );

    expect(
      client.signIn(email: 'a@b.c', password: 'wrong'),
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', 'Invalid email or password')),
    );
  });

  test('the JWT is fetched with the cookie, not a bearer header', () async {
    late http.Request sent;
    final client = NeonAuthClient(
      baseUrl: base,
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response('{"token":"eyJ.jwt.sig"}', 200);
      }),
    );

    final jwt =
        await client.fetchJwt('__Secure-neon-auth.session_token=abc123.sig');

    expect(sent.method, 'GET');
    expect(sent.url.toString(), '$base/token');
    expect(sent.headers['Cookie'], '__Secure-neon-auth.session_token=abc123.sig');
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(jwt, 'eyJ.jwt.sig');
  });

  test('an expired session says so', () async {
    final client = NeonAuthClient(
      baseUrl: base,
      httpClient: MockClient((_) async => http.Response('', 401)),
    );

    expect(
      client.fetchJwt('__Secure-neon-auth.session_token=old'),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
