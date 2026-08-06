// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'token_pair.dart';
import 'token_store.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthException implements Exception {
  const AuthException();
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException();
}

class AuthSession extends ChangeNotifier {
  AuthSession({
    required Dio authDio,
    required TokenStore tokenStore,
    DateTime Function()? now,
    this.refreshLeeway = const Duration(seconds: 30),
    this.scheduleProactiveRefresh = true,
  }) : _authDio = authDio,
       _tokenStore = tokenStore,
       _now = now ?? _utcNow;

  factory AuthSession.production() {
    return AuthSession(
      authDio: ApiConfig.createDio(),
      tokenStore: SecureTokenStore(),
    );
  }

  final Dio _authDio;
  final TokenStore _tokenStore;
  final DateTime Function() _now;
  final Duration refreshLeeway;
  final bool scheduleProactiveRefresh;

  AuthStatus _status = AuthStatus.initializing;
  TokenPair? _tokens;
  Future<TokenPair>? _refreshInFlight;
  Timer? _refreshTimer;
  bool _disposed = false;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<void> initialize() async {
    if (_status != AuthStatus.initializing) {
      return;
    }

    try {
      _tokens = await _tokenStore.read();
    } catch (_) {
      await _invalidateSession(clearStorage: false);
      return;
    }

    if (_tokens == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    if (_shouldRefresh(_tokens!)) {
      try {
        await _refreshTokens();
        return;
      } on SessionExpiredException {
        return;
      } on AuthException {
        // A temporary network failure should not force a re-login. The first
        // authenticated request will try the refresh again.
      }
    }

    _setStatus(AuthStatus.authenticated);
    _scheduleRefresh();
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _authDio.post<dynamic>(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final tokens = _tokensFromResponse(response.data);
      await _replaceTokens(tokens);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const InvalidCredentialsException();
      }
      throw const AuthException();
    } on FormatException {
      throw const AuthException();
    }
  }

  Future<String?> validAccessToken() async {
    final tokens = _tokens;
    if (tokens == null) {
      return null;
    }

    if (_shouldRefresh(tokens)) {
      return (await _refreshTokens()).accessToken;
    }
    return tokens.accessToken;
  }

  Future<String?> refreshAfterUnauthorized(String? rejectedAccessToken) async {
    final tokens = _tokens;
    if (tokens == null) {
      return null;
    }

    // Another request may already have rotated the pair while this response
    // was in flight. In that case retry with the current token without issuing
    // a second refresh using the newly rotated refresh token.
    if (rejectedAccessToken != null &&
        rejectedAccessToken != tokens.accessToken) {
      return tokens.accessToken;
    }

    return (await _refreshTokens()).accessToken;
  }

  Future<void> logout() async {
    final refreshToken = _tokens?.refreshToken;
    final serverLogout = refreshToken == null
        ? null
        : _authDio.post<void>(
            '/api/auth/logout',
            data: {'refreshToken': refreshToken},
          );

    Object? storageError;
    try {
      await _invalidateSession();
    } catch (error) {
      storageError = error;
    }

    if (serverLogout != null) {
      try {
        await serverLogout;
      } on DioException {
        // Local logout is final even when the server cannot be reached.
      }
    }

    if (storageError != null) {
      throw const AuthException();
    }
  }

  bool _shouldRefresh(TokenPair tokens) {
    return !tokens.expiresAt.isAfter(_now().add(refreshLeeway));
  }

  Future<TokenPair> _refreshTokens() async {
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<TokenPair> _performRefresh() async {
    final refreshToken = _tokens?.refreshToken;
    if (refreshToken == null) {
      throw const SessionExpiredException();
    }

    try {
      final response = await _authDio.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final tokens = _tokensFromResponse(response.data);
      await _replaceTokens(tokens);
      return tokens;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        await _invalidateSession();
        throw const SessionExpiredException();
      }
      throw const AuthException();
    } on FormatException {
      await _invalidateSession();
      throw const SessionExpiredException();
    }
  }

  TokenPair _tokensFromResponse(dynamic data) {
    if (data is! Map) {
      throw const FormatException('Invalid token response.');
    }
    return TokenPair.fromJson(
      Map<String, dynamic>.from(data),
      now: _now().toUtc(),
    );
  }

  Future<void> _replaceTokens(TokenPair tokens) async {
    try {
      await _tokenStore.write(tokens);
    } catch (_) {
      await _invalidateSession();
      throw const AuthException();
    }

    _tokens = tokens;
    _setStatus(AuthStatus.authenticated);
    _scheduleRefresh();
  }

  Future<void> _invalidateSession({bool clearStorage = true}) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _tokens = null;
    _setStatus(AuthStatus.unauthenticated);
    if (clearStorage) {
      await _tokenStore.clear();
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!scheduleProactiveRefresh || _tokens == null || _disposed) {
      return;
    }

    final refreshAt = _tokens!.expiresAt.subtract(refreshLeeway);
    final delay = refreshAt.difference(_now());
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(_runScheduledRefresh());
    });
  }

  Future<void> _runScheduledRefresh() async {
    try {
      await _refreshTokens();
    } on SessionExpiredException {
      // _performRefresh has already returned the app to the login screen.
    } on AuthException {
      if (_tokens != null && !_disposed) {
        _refreshTimer = Timer(const Duration(seconds: 30), () {
          unawaited(_runScheduledRefresh());
        });
      }
    }
  }

  void _setStatus(AuthStatus value) {
    _status = value;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _authDio.close();
    super.dispose();
  }
}
