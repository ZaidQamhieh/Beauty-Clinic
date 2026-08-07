import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_pair.dart';

abstract interface class TokenStore {
  Future<TokenPair?> read();

  Future<void> write(TokenPair tokens);

  Future<void> clear();
}

/// Persists the token pair in storage owned by this browser origin.
///
/// On Flutter web this is browser storage, not an operating-system keychain.
/// Code running in the page can access it, so the backend intentionally keeps
/// the refresh-token lifetime short to limit the impact of a leaked token.
class BrowserTokenStore implements TokenStore {
  BrowserTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'auth.access_token';
  static const _refreshTokenKey = 'auth.refresh_token';
  static const _expiresAtKey = 'auth.access_token_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<TokenPair?> read() async {
    final values = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _expiresAtKey),
    ]);

    if (values.every((value) => value == null)) {
      return null;
    }

    final accessToken = values[0];
    final refreshToken = values[1];
    final expiresAt = DateTime.tryParse(values[2] ?? '');
    if (accessToken == null || refreshToken == null || expiresAt == null) {
      await clear();
      return null;
    }

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
  }

  @override
  Future<void> write(TokenPair tokens) async {
    // Clear first so a refresh token that has just been rotated can never be
    // read again after a partial write. The new refresh token is written first.
    await clear();
    try {
      await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
      await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
      await _storage.write(
        key: _expiresAtKey,
        value: tokens.expiresAt.toUtc().toIso8601String(),
      );
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }
}
