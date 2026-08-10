import 'role.dart';

class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.role,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Role role;

  factory TokenPair.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresInSeconds = json['expiresInSeconds'];
    final role = Role.tryParse(json['role'] as String?);

    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing access token.');
    }
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const FormatException('Missing refresh token.');
    }
    if (expiresInSeconds is! num || expiresInSeconds <= 0) {
      throw const FormatException('Invalid access token expiry.');
    }
    // A role the app cannot place is a role it cannot gate on, so reject it.
    if (role == null) {
      throw const FormatException('Missing or unknown role.');
    }

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: (now ?? DateTime.now().toUtc()).add(
        Duration(seconds: expiresInSeconds.toInt()),
      ),
      role: role,
    );
  }
}
