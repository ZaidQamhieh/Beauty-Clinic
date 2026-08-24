import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'role.dart';
import 'token_pair.dart';
import 'token_store.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthException implements Exception {
  const AuthException();
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

class AccountAlreadyExistsException extends AuthException {
  const AccountAlreadyExistsException();
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException();
}

class AuthSession extends ChangeNotifier {
  AuthSession(
    this._authDio,
    this._tokenStore, {
    DateTime Function()? now,
    this.refreshLeeway = const Duration(seconds: 30),
    this.scheduleProactiveRefresh = true,
    this.scheduledRefreshRetryDelays = const [
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(seconds: 120),
      Duration(seconds: 240),
    ],
  }) : _now = now ?? _utcNow;

  factory AuthSession.production() {
    return AuthSession(ApiConfig.createDio(), BrowserTokenStore());
  }

  final Dio _authDio;
  final TokenStore _tokenStore;
  final DateTime Function() _now;
  final Duration refreshLeeway;
  final bool scheduleProactiveRefresh;
  final List<Duration> scheduledRefreshRetryDelays;

  AuthStatus _status = AuthStatus.initializing;
  TokenPair? _tokens;
  Future<TokenPair>? _refreshInFlight;
  Timer? _refreshTimer;
  int _scheduledRefreshFailures = 0;
  bool _disposed = false;

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// The signed-in user's role, renewed on every rotation; null while signed out.
  Role? get role => _tokens?.role;

  String? get userId {
    final token = _tokens?.accessToken;
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return (payload as Map<String, dynamic>)['uid']?.toString();
    } catch (_) {
      return null;
    }
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<void> initialize() async {
    if (_status != AuthStatus.initializing) {
      return;
    }

    try {
      _tokens = await _tokenStore.read();
    } catch (_) {
      // An unreadable value cannot recover on its own. Clear it so the next
      // launch starts from a clean, logged-out state.
      await _invalidateSession();
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

  /// Creates a patient account. The server deliberately ignores roles here so
  /// a public registration can never create an admin, staff, or doctor user.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authDio.post<dynamic>(
        '/api/auth/register',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      final tokens = _tokensFromResponse(response.data);
      await _replaceTokens(tokens);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw const AccountAlreadyExistsException();
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
      await _invalidateSession(reportStorageError: true);
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
    final currentTokens = _tokens;
    if (currentTokens == null) {
      throw const SessionExpiredException();
    }

    // A sibling browser tab may have rotated the refresh token since this tab
    // started. Read storage immediately before refreshing and adopt a newer
    // pair instead of submitting the stale in-memory token.
    TokenPair? storedTokens;
    try {
      storedTokens = await _tokenStore.read();
    } catch (_) {
      await _invalidateSession();
      throw const SessionExpiredException();
    }
    if (storedTokens == null) {
      await _invalidateSession();
      throw const SessionExpiredException();
    }
    if (!_sameTokenPair(currentTokens, storedTokens)) {
      _adoptStoredTokens(storedTokens);
      if (!_shouldRefresh(storedTokens)) {
        return storedTokens;
      }
    }

    try {
      final response = await _authDio.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': storedTokens.refreshToken},
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
    _scheduledRefreshFailures = 0;
    _setStatus(AuthStatus.authenticated);
    _scheduleRefresh();
  }

  void _adoptStoredTokens(TokenPair tokens) {
    _tokens = tokens;
    _scheduledRefreshFailures = 0;
    _setStatus(AuthStatus.authenticated);
    _scheduleRefresh();
  }

  bool _sameTokenPair(TokenPair first, TokenPair second) {
    return first.accessToken == second.accessToken &&
        first.refreshToken == second.refreshToken &&
        first.expiresAt == second.expiresAt;
  }

  Future<void> _invalidateSession({bool reportStorageError = false}) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _scheduledRefreshFailures = 0;
    _tokens = null;
    _setStatus(AuthStatus.unauthenticated);
    try {
      await _tokenStore.clear();
    } catch (_) {
      if (reportStorageError) {
        rethrow;
      }
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
      if (_tokens == null || _disposed) {
        return;
      }

      if (_scheduledRefreshFailures >= scheduledRefreshRetryDelays.length) {
        await _invalidateSession();
        return;
      }

      final retryDelay = scheduledRefreshRetryDelays[_scheduledRefreshFailures];
      _scheduledRefreshFailures += 1;
      _refreshTimer = Timer(retryDelay, () {
        unawaited(_runScheduledRefresh());
      });
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
