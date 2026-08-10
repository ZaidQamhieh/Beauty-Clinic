package com.example.backend.security;

import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.RefreshTokenRepository;
import com.example.backend.services.AccessTokenService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

// Rejects an access token once its session is gone, or the account is disabled or re-roled.
@Component
@RequiredArgsConstructor
class SessionTokenValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2Error MALFORMED_SESSION = new OAuth2Error(
            "invalid_token", "Token is missing a valid session claim", null
    );

    private static final OAuth2Error MALFORMED_USER = new OAuth2Error(
            "invalid_token", "Token is missing a valid user claim", null
    );

    // Deliberately vague: whoever holds this token is not necessarily the account holder.
    private static final OAuth2Error STALE = new OAuth2Error(
            "invalid_token", "Session is no longer valid", null
    );

    private final RefreshTokenRepository refreshTokens;

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        Optional<UUID> sessionId = uuidClaim(token, AccessTokenService.SESSION_CLAIM);
        if (sessionId.isEmpty()) {
            return OAuth2TokenValidatorResult.failure(MALFORMED_SESSION);
        }

        Optional<UUID> userId = uuidClaim(token, AccessTokenService.USER_ID_CLAIM);
        if (userId.isEmpty()) {
            return OAuth2TokenValidatorResult.failure(MALFORMED_USER);
        }

        // One read, and it ties the two claims: a session must belong to the id named.
        boolean stillCurrent = refreshTokens.findSessionOwner(sessionId.get(), userId.get())
                .filter(UserAccount::isEnabled)
                .filter(account -> carriesCurrentRole(token, account))
                .isPresent();

        if (!stillCurrent) {
            return OAuth2TokenValidatorResult.failure(STALE);
        }

        return OAuth2TokenValidatorResult.success();
    }

    // A role change invalidates the token; refreshing mints one carrying the new authorities.
    private boolean carriesCurrentRole(Jwt token, UserAccount account) {
        var authorities = token.getClaimAsStringList(AccessTokenService.AUTHORITIES_CLAIM);
        return authorities != null && authorities.contains(account.getRole().authority().getAuthority());
    }

    private Optional<UUID> uuidClaim(Jwt token, String claim) {
        try {
            return Optional.of(UUID.fromString(token.getClaimAsString(claim)));
        } catch (IllegalArgumentException | NullPointerException malformed) {
            return Optional.empty();
        }
    }
}
