class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt; 

  factory TokenPair.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresInSeconds = json['expiresInSeconds'];

    if (accessToken is! String || accessToken.isEmpty) {
      throw const FormatException('Missing access token.');
    }
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const FormatException('Missing refresh token.');
    }
    if (expiresInSeconds is! num || expiresInSeconds <= 0) {
      throw const FormatException('Invalid access token expiry.');
    }

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: (now ?? DateTime.now().toUtc()).add(
        Duration(seconds: expiresInSeconds.toInt()),
      ),
    );
  }
}
