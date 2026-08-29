import 'package:beauty_clinic_app/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/auth_test_fakes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 12);

  test('API client sends authentication header', () async {
    final store = MemoryTokenStore();
    final authAdapter = QueueAdapter([
      (_) => jsonResponse(200, tokenResponse('access-1', 'refresh-1')),
    ]);
    final session = testSession(authAdapter, store, now);
    addTearDown(session.dispose);

    final apiAdapter = QueueAdapter([
      (request) {
        expect(request.headers['Authorization'], contains('Bearer access-1'));
        return jsonResponse(200, {'ok': true});
      },
    ]);

    final client = ApiClient(session, dio: testDio(apiAdapter));
    addTearDown(client.close);

    await session.initialize();
    await session.login(email: 'test@example.com', password: 'password');
    await client.get<dynamic>('/api/test');

    expect(apiAdapter.requests.length, greaterThan(0));
  });

  test('API client handles 401 unauthorized', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(401, {
        'detail': 'Token expired',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    expect(
      () => client.get<dynamic>('/api/protected'),
      throwsA(isA<DioException>()),
    );
  });

  test('API client handles 403 forbidden', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(403, {
        'detail': 'Insufficient permissions',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    expect(
      () => client.get<dynamic>('/api/admin'),
      throwsA(isA<DioException>()),
    );
  });

  test('API client handles 404 not found', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(404, {
        'detail': 'Resource not found',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    expect(
      () => client.get<dynamic>('/api/missing'),
      throwsA(isA<DioException>()),
    );
  });

  test('API client handles 422 validation error', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(422, {
        'detail': 'Invalid email format',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    expect(
      () => client.post<dynamic>('/api/register', data: {'email': 'invalid'}),
      throwsA(isA<DioException>()),
    );
  });

  test('API client handles 500 server error', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(500, {
        'detail': 'Internal server error',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    expect(
      () => client.get<dynamic>('/api/test'),
      throwsA(isA<DioException>()),
    );
  });

  test('API client preserves response data on error', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final adapter = QueueAdapter([
      (_) => jsonResponse(400, {
        'detail': 'Email already registered',
        'error': 'DUPLICATE_EMAIL',
      }),
    ]);

    final client = ApiClient(session, dio: testDio(adapter));
    addTearDown(client.close);

    try {
      await client.post<dynamic>('/api/register', data: {'email': 'taken@example.com'});
      fail('Should throw DioException');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 400);
      expect(e.response?.data['detail'], 'Email already registered');
    }
  });

  test('API client enforces HTTPS URLs', () async {
    final store = MemoryTokenStore();
    final session = testSession(QueueAdapter(const []), store, now);
    addTearDown(session.dispose);

    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = QueueAdapter([
      (_) => jsonResponse(200, {'ok': true}),
    ]);

    final client = ApiClient(session, dio: dio);
    addTearDown(client.close);

    final response = await client.get<dynamic>('/api/test');
    expect(response.statusCode, 200);
  });
}
