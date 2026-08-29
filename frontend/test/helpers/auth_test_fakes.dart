import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beauty_clinic_app/auth/auth_session.dart';
import 'package:beauty_clinic_app/auth/role.dart';
import 'package:beauty_clinic_app/auth/token_pair.dart';
import 'package:beauty_clinic_app/auth/token_store.dart';
import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';

AuthSession testSession(
  QueueAdapter adapter,
  TokenStore store,
  DateTime now, {
  bool scheduleProactiveRefresh = false,
  List<Duration> scheduledRefreshRetryDelays = const [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 240),
  ],
}) {
  return AuthSession(
    testDio(adapter),
    store,
    now: () => now,
    refreshLeeway: const Duration(seconds: 30),
    scheduleProactiveRefresh: scheduleProactiveRefresh,
    scheduledRefreshRetryDelays: scheduledRefreshRetryDelays,
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
  String role = 'PATIENT',
}) {
  return {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': 'Bearer',
    'expiresInSeconds': expiresInSeconds,
    'role': role,
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
  Object? readError;
  int clearCount = 0;
  void Function(TokenPair tokens)? onWrite;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
    readError = null;
  }

  @override
  Future<TokenPair?> read() async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return value;
  }

  @override
  Future<void> write(TokenPair tokens) async {
    value = tokens;
    onWrite?.call(tokens);
  }
}

ResponseBody jsonListResponse(int statusCode, List<dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class AuthSessionHarness {
  AuthSessionHarness(this.session, this.client);

  final AuthSession session;
  final ApiClient client;

  void dispose() {
    client.close();
    session.dispose();
  }
}

AuthSessionHarness adminHarness(
  QueueAdapter adapter, {
  Role role = Role.admin,
}) {
  final session = testSession(
    QueueAdapter(const []),
    MemoryTokenStore()
      ..value = TokenPair(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2026, 8, 11, 13),
        role: role,
      ),
    DateTime.utc(2026, 8, 11, 12),
  );
  return AuthSessionHarness(session, ApiClient(session, dio: testDio(adapter)));
}
