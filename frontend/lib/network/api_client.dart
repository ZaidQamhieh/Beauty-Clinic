import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../config/api_config.dart';

class ApiClient {
  static const authorizationHeader = 'Authorization';
  ApiClient(this._authSession, {Dio? dio})
    : dio = dio ?? ApiConfig.createDio() {
    this.dio.interceptors.add(
      QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const _retriedAfterRefresh = 'retriedAfterRefresh';

  final AuthSession _authSession;
  final Dio dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return dio.put<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) {
    return dio.delete<T>(path, data: data);
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final accessToken = await _authSession.validAccessToken();
      if (accessToken != null) {
        options.headers[authorizationHeader] = 'Bearer $accessToken';
      }
      handler.next(options);
    } on AuthException catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        request.extra[_retriedAfterRefresh] == true) {
      handler.next(error);
      return;
    }

    final rejectedAccessToken = _bearerToken(
      request.headers[authorizationHeader],
    );

    try {
      final accessToken = await _authSession.refreshAfterUnauthorized(
        rejectedAccessToken,
      );
      if (accessToken == null) {
        handler.next(error);
        return;
      }

      final retry = request.copyWith(
        headers: {
          ...request.headers,
          authorizationHeader: 'Bearer $accessToken',
        },
        extra: {...request.extra, _retriedAfterRefresh: true},
      );
      handler.resolve(await dio.fetch<dynamic>(retry));
    } on AuthException {
      // An invalid refresh token has already cleared the session. Passing the
      // original 401 lets callers stop while the root UI returns to login.
      handler.next(error);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  String? _bearerToken(Object? authorization) {
    if (authorization is! String || !authorization.startsWith('Bearer ')) {
      return null;
    }
    return authorization.substring('Bearer '.length);
  }

  void close() {
    dio.close();
  }
}
