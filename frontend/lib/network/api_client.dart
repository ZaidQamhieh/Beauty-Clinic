import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/auth_session.dart';
import '../config/api_config.dart';

/// Signed in, but this record isn't theirs.
class ForbiddenException implements Exception {
  const ForbiddenException();
}

class _CacheEntry {
  _CacheEntry(this.data, this.storedAt);
  final dynamic data;
  final DateTime storedAt;
}

class ApiClient {
  static const authorizationHeader = 'Authorization';
  ApiClient(this._authSession, {Dio? dio})
    : dio = dio ?? ApiConfig.createDio() {
    this.dio.interceptors.add(
      QueuedInterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
    _cachedForUserId = _authSession.userId;
    _authSession.addListener(_dropCacheIfUserChanged);
  }

  static const _retriedAfterRefresh = 'retriedAfterRefresh';

  final AuthSession _authSession;
  final Dio dio;
  final Map<String, _CacheEntry> _cache = {};

  // Never leak one user's data to another.
  String? _cachedForUserId;

  /// For writes bypassing [post], like the chatbot.
  void invalidateCache() {
    _cache.clear();
    _revalidating.clear();
    _viewState.clear();
  }

  /// Parsed screen data kept across route disposal.
  final Map<String, Object?> _viewState = {};

  T? readViewState<T>(String key) {
    final value = _viewState[key];
    return value is T ? value : null;
  }

  void writeViewState(String key, Object? value) {
    _viewState[key] = value;
  }

  void _dropCacheIfUserChanged() {
    final userId = _authSession.userId;
    if (userId == _cachedForUserId) return;
    _cachedForUserId = userId;
    _cache.clear();
    _revalidating.clear();
    _viewState.clear();
  }

  // Live only; a stale slot double-books.
  static final _neverCache = RegExp(
    r'^/api/appointments'
    r'|^/api/doctors/[0-9a-fA-F-]+/availability',
  );

  // Read-only lists, never the slot picker.
  static final _appointmentDisplay = RegExp(
    r'^/api/appointments/me/(upcoming|history)$'
    r'|^/api/appointments/me/schedule$'
    r'|^/api/appointments/patients/[0-9a-fA-F-]+/(upcoming|history)$'
    r'|^/api/appointments/all$'
    r'|^/api/doctors/[0-9a-fA-F-]+/availability/calendar$',
  );

  // Served instantly, then refreshed in the background.
  static const _fresh = Duration(minutes: 5);
  static const _stale = Duration(minutes: 30);

  // Booking moves these; keep the window tight.
  static const _appointmentFresh = Duration(seconds: 10);
  static const _appointmentStale = Duration(seconds: 60);

  final Set<String> _revalidating = {};

  String _cacheKey(String path, Map<String, dynamic>? queryParameters) {
    if (queryParameters == null || queryParameters.isEmpty) return path;
    final sorted = queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$path?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final isDisplayList = _appointmentDisplay.hasMatch(path);
    if (_neverCache.hasMatch(path) && !isDisplayList) {
      return dio.get<T>(path, queryParameters: queryParameters);
    }

    final fresh = isDisplayList ? _appointmentFresh : _fresh;
    final stale = isDisplayList ? _appointmentStale : _stale;

    final key = _cacheKey(path, queryParameters);
    final cached = _cache[key];
    final age = cached == null
        ? null
        : DateTime.now().difference(cached.storedAt);

    if (cached != null && age! < stale) {
      // Stale but usable; refresh behind it.
      if (age >= fresh) {
        _revalidate<T>(key, path, queryParameters);
      }
      return Response<T>(
        data: cached.data as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }

    final response = await dio.get<T>(path, queryParameters: queryParameters);
    if (response.statusCode == 200) {
      _cache[key] = _CacheEntry(response.data, DateTime.now());
    }
    return response;
  }

  void _revalidate<T>(
    String key,
    String path,
    Map<String, dynamic>? queryParameters,
  ) {
    if (!_revalidating.add(key)) return;
    unawaited(
      dio
          .get<T>(path, queryParameters: queryParameters)
          .then((response) {
            if (response.statusCode == 200) {
              _cache[key] = _CacheEntry(response.data, DateTime.now());
            }
          })
          // Keep serving the stale copy on failure.
          .onError((_, _) {})
          .whenComplete(() => _revalidating.remove(key)),
    );
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    final response = await dio.post<T>(path, data: data);
    _cache.clear();
    return response;
  }

  Future<Response<T>> put<T>(String path, {Object? data}) async {
    final response = await dio.put<T>(path, data: data);
    _cache.clear();
    return response;
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) async {
    final response = await dio.delete<T>(path, data: data);
    _cache.clear();
    return response;
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
    final statusCode = error.response?.statusCode;

    if (statusCode == 403) {
      handler.next(
        DioException(
          requestOptions: request,
          response: error.response,
          type: error.type,
          error: const ForbiddenException(),
        ),
      );
      return;
    }

    if (statusCode != 401 || request.extra[_retriedAfterRefresh] == true) {
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
      // Session already cleared; pass 401 through.
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
    _authSession.removeListener(_dropCacheIfUserChanged);
    _cache.clear();
    dio.close();
  }
}
