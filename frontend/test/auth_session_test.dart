import 'dart:async';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('login persists both tokens', () async {
    final store = MemoryTokenStore();
    final adapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(adapter, store, now);
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');

    expect(session.status, AuthStatus.authenticated);
    expect(store.value?.accessToken, 'access-1');
    expect(store.value?.refreshToken, 'refresh-1');
  });

  test('logout clears the pair and calls the logout endpoint', () async {
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

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
    expect(adapter.requests[1].path, '/api/auth/logout');
    expect(adapter.requests[1].data, {'refreshToken': 'refresh-1'});
  });

  test('unreadable storage is cleared during initialization', () async {
    final store = MemoryTokenStore()..readError = const FormatException();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    await session.initialize();

    expect(session.status, AuthStatus.unauthenticated);
    expect(store.clearCount, 1);
    expect(store.readError, isNull);
  });

  test('proactive refresh runs before access-token expiry', () async {
    final store = MemoryTokenStore();
    final refreshed = Completer<void>();
    store.onWrite = (tokens) {
      if (tokens.accessToken == 'access-2') {
        refreshed.complete();
      }
    };
    final adapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', expiresInSeconds: 20),
      ),
      (_) => jsonResponse(200, tokenResponse('access-2', 'refresh-2')),
    ]);
    final session = testSession(
      adapter,
      store,
      now,
      scheduleProactiveRefresh: true,
    );
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    await refreshed.future.timeout(const Duration(seconds: 2));

    expect(adapter.requests[1].path, '/api/auth/refresh');
    expect(adapter.requests[1].data, {'refreshToken': 'refresh-1'});
    expect(store.value?.accessToken, 'access-2');
    expect(store.value?.refreshToken, 'refresh-2');
  });

  test('scheduled refresh backs off and eventually logs out', () async {
    final store = MemoryTokenStore();
    final loggedOut = Completer<void>();
    final adapter = QueueAdapter([
      (_) => jsonResponse(
        200,
        tokenResponse('access-1', 'refresh-1', expiresInSeconds: 20),
      ),
      for (var attempt = 0; attempt < 5; attempt += 1)
        (_) => jsonResponse(500, {'detail': 'offline'}),
    ]);
    final session = testSession(
      adapter,
      store,
      now,
      scheduleProactiveRefresh: true,
      scheduledRefreshRetryDelays: const [
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );
    addTearDown(session.dispose);

    await session.initialize();
    await session.login(email: 'owner@example.com', password: 'password');
    session.addListener(() {
      if (session.status == AuthStatus.unauthenticated &&
          !loggedOut.isCompleted) {
        loggedOut.complete();
      }
    });
    await loggedOut.future.timeout(const Duration(seconds: 2));

    expect(adapter.requests, hasLength(6));
    expect(session.status, AuthStatus.unauthenticated);
    expect(store.value, isNull);
  });
}
