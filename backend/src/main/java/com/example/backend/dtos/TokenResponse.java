package com.example.backend.dtos;

// The token's own authority, restated so the client shapes its UI without decoding the JWT.
public record TokenResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresInSeconds,
    String role
) {

}