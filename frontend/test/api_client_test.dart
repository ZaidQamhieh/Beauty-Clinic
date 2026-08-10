import 'package:beauty_clinic/auth/auth_session.dart';
import 'package:beauty_clinic/auth/role.dart';
import 'package:beauty_clinic/auth/token_pair.dart';
import 'package:beauty_clinic/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('authenticated requests include the bearer token', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await client.get<dynamic>('/api/appointments');

    expect(
      apiAdapter.requests.single.headers[ApiClient.authorizationHeader],
      'Bearer access-1',
    );
  });

  test('a request refreshes before expiry and uses the new pair', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('expiring-access', 'refresh-1', expiresInSeconds: 20),
      ),
      (_) => jsonResponse(200, tokenResponse('fresh-access', 'refresh-2')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await client.get<dynamic>('/api/appointments');

    expect(authAdapter.requests[1].path, '/api/auth/refresh');
    expect(authAdapter.requests[1].data, {'refreshToken': 'refresh-1'});
    expect(store.value?.refreshToken, 'refresh-2');
    expect(
      apiAdapter.requests.single.headers[ApiClient.authorizationHeader],
      'Bearer fresh-access',
    );
  });

  test('the first 401 rotates the pair and retries exactly once', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => jsonResponse(200, tokenResponse('access-2', 'refresh-2')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'expired'}),
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    final response = await client.get<dynamic>('/api/appointments');

    expect(response.statusCode, 200);
    expect(authAdapter.requests[1].data, {'refreshToken': 'refresh-1'});
    expect(store.value?.accessToken, 'access-2');
    expect(store.value?.refreshToken, 'refresh-2');
    expect(
      apiAdapter.requests.map(
        (request) => request.headers[ApiClient.authorizationHeader],
      ),
      ['Bearer access-1', 'Bearer access-2'],
    );
  });

  test('refresh adopts a token pair rotated by another tab', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(authAdapter, store, now);
    final siblingPair = TokenPair(
      accessToken: 'sibling-access',
      refreshToken: 'sibling-refresh',
      expiresAt: now.add(const Duration(minutes: 15)),
      role: Role.patient,
    );
    final apiAdapter = QueueAdapter([
      (_) {
        store.value = siblingPair;
        return jsonResponse(401, {'detail': 'rotated elsewhere'});
      },
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    final response = await client.get<dynamic>('/api/appointments');

    expect(response.statusCode, 200);
    expect(authAdapter.requests, hasLength(1));
    expect(
      apiAdapter.requests.map(
        (request) => request.headers[ApiClient.authorizationHeader],
      ),
      ['Bearer access-1', 'Bearer sibling-access'],
    );
    expect(session.status, AuthStatus.authenticated);
  });

  test('a revoked session 401 clears the session for the UI', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) =>
          jsonResponse(200, tokenResponse('revoked-access', 'revoked-refresh')),
      (_) => jsonResponse(401, {'detail': 'refresh revoked'}),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'access revoked'}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await expectLater(
      client.get<dynamic>('/api/appointments'),
      throwsA(isA<DioException>()),
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(authAdapter.requests[1].data, {'refreshToken': 'revoked-refresh'});
  });
}
