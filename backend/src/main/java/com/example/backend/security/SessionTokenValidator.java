package com.example.backend.security;

import com.example.backend.repository.RefreshTokenRepository;
import com.example.backend.service.AccessTokenService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.UUID;

// Rejects an access token once its refresh-token row is gone (e.g. logout),
// instead of waiting for the token to expire on its own.
@Component
@RequiredArgsConstructor
class SessionTokenValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2Error REVOKED = new OAuth2Error(
            "invalid_token", "Session has been revoked", null
    );

    private final RefreshTokenRepository refreshTokens;

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        String sid = token.getClaimAsString(AccessTokenService.SESSION_CLAIM);

        UUID sessionId;
        try {
            sessionId = UUID.fromString(sid);
        } catch (IllegalArgumentException | NullPointerException malformed) {
            return OAuth2TokenValidatorResult.failure(REVOKED);
        }

        return refreshTokens.existsById(sessionId)
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(REVOKED);
    }
}
