import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beauty_clinic/auth/auth_session.dart';
import 'package:beauty_clinic/auth/token_pair.dart';
import 'package:beauty_clinic/auth/token_store.dart';
import 'package:beauty_clinic/main.dart';
import 'package:beauty_clinic/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('login persists both tokens and authenticates later requests', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(authAdapter, store, now);
    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(200, {'ok': true}),
    ]);
    final client = ApiClient(authSession: session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await client.get<dynamic>('/api/appointments');

    expect(store.value?.accessToken, 'access-1');
    expect(store.value?.refreshToken, 'refresh-1');
    expect(
      apiAdapter.requests.single.headers[ApiClient.authorizationHeader],
      'Bearer access-1',
    );
  });

  testWidgets('a login 401 shows only the generic credentials message', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'raw server secret'}),
    ]);
    final session = testSession(authAdapter, store, now);
    addTearDown(session.dispose);

    await tester.pumpWidget(MyApp(authSession: session));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(find.textContaining('raw server secret'), findsNothing);
  });

  test(
    'a request refreshes before expiry and uses the new access token',
    () async {
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
      final client = ApiClient(authSession: session, dio: testDio(apiAdapter));
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
    },
  );

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
    final client = ApiClient(authSession: session, dio: testDio(apiAdapter));
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

  test('logout clears the pair and calls the logout endpoint', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
      (_) => ResponseBody.fromString('', 204),
    ]);
    final session = testSession(authAdapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await session.logout();

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(authAdapter.requests[1].path, '/api/auth/logout');
    expect(authAdapter.requests[1].data, {'refreshToken': 'refresh-1'});
  });

  test('a revoked session 401 clears the session for the UI', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) =>
          jsonResponse(200, tokenResponse('revoked-access', 'revoked-refresh')),
      (_) => jsonResponse(401, {'detail': 'refresh revoked'}),
    ]);
    final session = testSession(authAdapter, store, now);
    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');

    final apiAdapter = QueueAdapter([
      (_) => jsonResponse(401, {'detail': 'access revoked'}),
    ]);
    final client = ApiClient(authSession: session, dio: testDio(apiAdapter));
    addTearDown(() {
      client.close();
      session.dispose();
    });

    await expectLater(
      client.get<dynamic>('/api/appointments'),
      throwsA(isA<DioException>()),
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(authAdapter.requests[1].data, {'refreshToken': 'revoked-refresh'});
  });

  testWidgets('an unauthenticated session renders login without an API error', (
    tester,
  ) async {
    final session = testSession(
      QueueAdapter(const []),
      MemoryTokenStore(),
      now,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(MyApp(authSession: session));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('access revoked'), findsNothing);
    expect(find.textContaining('refresh revoked'), findsNothing);
  });
}

AuthSession testSession(
  QueueAdapter adapter,
  MemoryTokenStore store,
  DateTime now,
) {
  return AuthSession(
    authDio: testDio(adapter),
    tokenStore: store,
    now: () => now,
    refreshLeeway: const Duration(seconds: 30),
    scheduleProactiveRefresh: false,
  );
}

Dio testDio(QueueAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> tokenResponse(
  String accessToken,
  String refreshToken, {
  int expiresInSeconds = 900,
}) {
  return {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': 'Bearer',
    'expiresInSeconds': expiresInSeconds,
  };
}

ResponseBody jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

typedef AdapterHandler =
    FutureOr<ResponseBody> Function(RequestOptions request);

class QueueAdapter implements HttpClientAdapter {
  QueueAdapter(Iterable<AdapterHandler> handlers)
    : _handlers = Queue.of(handlers);

  final Queue<AdapterHandler> _handlers;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_handlers.isEmpty) {
      throw StateError(
        'No response queued for ${options.method} ${options.path}',
      );
    }
    return _handlers.removeFirst()(options);
  }

  @override
  void close({bool force = false}) {}
}

class MemoryTokenStore implements TokenStore {
  TokenPair? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<TokenPair?> read() async => value;

  @override
  Future<void> write(TokenPair tokens) async {
    value = tokens;
  }
}
