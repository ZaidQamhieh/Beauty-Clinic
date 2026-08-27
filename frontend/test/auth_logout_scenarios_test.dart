import 'dart:async';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('a rotation landing after logout cannot sign the user back in', () async {
    final store = MemoryTokenStore();
    final rotationGate = Completer<void>();
    final adapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', expiresInSeconds: 20),
      ),
      (_) async {
        await rotationGate.future;
        return jsonResponse(200, tokenResponse('access-2', 'refresh-2'));
      },
      (_) => ResponseBody.fromString('', 204),
    ]);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');

    final rotation = session.validAccessToken();
    await Future<void>.delayed(Duration.zero);

    final signOut = session.logout();
    rotationGate.complete();
    await rotation;
    await signOut;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    // Revokes the token now live server-side.
    expect(adapter.requests.last.path, '/api/auth/logout');
    expect(adapter.requests.last.data, {'refreshToken': 'refresh-2'});
  });

  test('a sign-out in another tab ends this one too', () async {
    final store = MemoryTokenStore();
    final adapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', expiresInSeconds: 20),
      ),
    ]);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');

    // The sibling tab cleared shared storage.
    store.value = null;

    await expectLater(
      session.validAccessToken(),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(adapter.requests, hasLength(1));
  });

  test('signing in again after a revoked-session sign-out works', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => jsonResponse(401, {'detail': 'refresh revoked'}),
      (_) => jsonResponse(200, tokenResponse('access-3', 'refresh-3')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'access revoked'}),
      (_) => jsonResponse(200, {'ok': true}),
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

    await session.login(email: 'owner@example.com', password: 'password');
    final response = await client.get<dynamic>('/api/appointments');

    expect(session.status, AuthStatus.authenticated);
    expect(response.statusCode, 200);
    expect(
      apiAdapter.requests.last.headers[ApiClient.authorizationHeader],
      'Bearer access-3',
    );
  });

  test('a request after sign-out carries no bearer token', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => ResponseBody.fromString('', 204),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'no token'}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await session.logout();

    await expectLater(
      client.get<dynamic>('/api/appointments'),
      throwsA(isA<DioException>()),
    );

    expect(
      apiAdapter.requests.single.headers.containsKey(
        ApiClient.authorizationHeader,
      ),
      isFalse,
    );
    // No retry; nothing left to refresh.
    expect(authAdapter.requests, hasLength(2));
  });

  test('a 403 is surfaced without ending the session', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(403, {'detail': 'not yours'}),
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
      throwsA(
        isA<DioException>().having(
          (error) => error.error,
          'error',
          isA<ForbiddenException>(),
        ),
      ),
    );

    expect(session.status, AuthStatus.authenticated);
    expect(store.value?.accessToken, 'access-1');
  });

  test('a 401 that survives the retry signs the user out', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => jsonResponse(200, tokenResponse('access-2', 'refresh-2')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'stale'}),
      (_) => jsonResponse(401, {'detail': 'still stale'}),
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

    expect(apiAdapter.requests, hasLength(2));
    expect(authAdapter.requests, hasLength(2));
    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
  });

  test('a 500 on the retry keeps the session', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => jsonResponse(200, tokenResponse('access-2', 'refresh-2')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'stale'}),
      (_) => jsonResponse(500, {'detail': 'backend fell over'}),
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

    expect(session.status, AuthStatus.authenticated);
    expect(store.value?.accessToken, 'access-2');
  });

  test('back-to-back requests share one rotation', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => jsonResponse(200, tokenResponse('access-2', 'refresh-2')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'expired'}),
      (_) => jsonResponse(200, {'ok': true}),
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');

    await Future.wait([
      client.get<dynamic>('/api/appointments'),
      client.get<dynamic>('/api/appointments/day-version'),
    ]);

    expect(authAdapter.requests.where((r) => r.path == '/api/auth/refresh'),
        hasLength(1));
    expect(
      apiAdapter.requests.last.headers[ApiClient.authorizationHeader],
      'Bearer access-2',
    );
  });

  test('a restart after sign-out starts signed out', () async {
    final store = MemoryTokenStore();
    final adapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => ResponseBody.fromString('', 204),
    ]);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await session.logout();

    final restarted = testSession(QueueAdapter(const []), store, now);
    addTearDown(restarted.dispose);
    await restarted.initialize();

    expect(restarted.status, AuthStatus.unauthenticated);
  });

  test('a restart on a revoked stored session ends signed out', () async {
    final store = MemoryTokenStore();
    final seedAdapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', expiresInSeconds: 20),
      ),
    ]);
    final seed = testSession(seedAdapter, store, now);
    addTearDown(seed.dispose);
    await seed.initialize();
    await seed.login(email: 'owner@example.com', password: 'password');

    final restartAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'refresh revoked'}),
    ]);
    final restarted = testSession(restartAdapter, store, now);
    addTearDown(restarted.dispose);

    await restarted.initialize();

    expect(restarted.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(restartAdapter.requests.single.path, '/api/auth/refresh');
  });

  test('the session survives a backend that cannot be reached', () async {
    final store = MemoryTokenStore();
    final seedAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final seed = testSession(seedAdapter, store, now);
    addTearDown(seed.dispose);
    await seed.initialize();
    await seed.login(email: 'owner@example.com', password: 'password');

    final apiAdapter = QueueAdapter([
      (request) => throw DioException.connectionError(
        requestOptions: request,
        reason: 'offline',
      ),
    ]);
    final client = ApiClient(seed, dio: testDio(apiAdapter));
    addTearDown(client.close);

    await expectLater(
      client.get<dynamic>('/api/appointments'),
      throwsA(isA<DioException>()),
    );

    expect(seed.status, AuthStatus.authenticated);
    expect(store.value?.accessToken, 'access-1');
  });
}
