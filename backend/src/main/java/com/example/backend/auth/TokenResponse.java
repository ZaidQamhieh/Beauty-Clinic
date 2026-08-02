package com.example.backend.auth;

public record TokenResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresInSeconds
) {

}
