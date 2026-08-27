package com.example.backend.security;

import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.RefreshTokenRepository;
import com.example.backend.entities.ActivityAction;
import com.example.backend.services.AccessTokenService;
import com.example.backend.services.ActivityLogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

// Rejects tokens whose session or account changed.
@Component
@RequiredArgsConstructor
@Slf4j
class SessionTokenValidator implements OAuth2TokenValidator<Jwt> {

    private static final OAuth2Error MALFORMED_SESSION = new OAuth2Error(
            "invalid_token", "Token is missing a valid session claim", null
    );

    private static final OAuth2Error MALFORMED_USER = new OAuth2Error(
            "invalid_token", "Token is missing a valid user claim", null
    );

    // Vague: holder may not be owner.
    private static final OAuth2Error STALE = new OAuth2Error(
            "invalid_token", "Session is no longer valid", null
    );

    private final RefreshTokenRepository refreshTokens;
    private final ActivityLogService activityLogs;

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

        // One read ties the two claims together.
        Optional<UserAccount> owner = refreshTokens.findSessionOwner(sessionId.get(), userId.get());

        // Account may be gone; name no actor.
        if (owner.isEmpty()) {
            audit(null, ActivityAction.STALE_SESSION_REJECTED,
                    "refresh_token", sessionId.get());
            return OAuth2TokenValidatorResult.failure(STALE);
        }

        UserAccount account = owner.get();

        if (!account.isEnabled()) {
            audit(account.getId(), ActivityAction.DISABLED_ACCOUNT_REJECTED,
                    "user_account", account.getId());
            return OAuth2TokenValidatorResult.failure(STALE);
        }

        if (!carriesCurrentRole(token, account)) {
            audit(account.getId(), ActivityAction.ROLE_CHANGE_REJECTED,
                    "user_account", account.getId());
            return OAuth2TokenValidatorResult.failure(STALE);
        }

        return OAuth2TokenValidatorResult.success();
    }

    // Logging never upgrades 401 to 500.
    private void audit(UUID actorId, ActivityAction action, String entityType, UUID entityId) {
        try {
            activityLogs.recordIndependently(actorId, null, action, entityType, entityId);
        } catch (RuntimeException unloggable) {
            log.warn("Could not record {}: {}", action, unloggable.toString());
        }
    }

    // Exactly the current role, nothing extra.
    private boolean carriesCurrentRole(Jwt token, UserAccount account) {
        var authorities = token.getClaimAsStringList(AccessTokenService.AUTHORITIES_CLAIM);
        return authorities != null
                && authorities.equals(List.of(account.getRole().authority().getAuthority()));
    }

    private Optional<UUID> uuidClaim(Jwt token, String claim) {
        try {
            return Optional.of(UUID.fromString(token.getClaimAsString(claim)));
        } catch (IllegalArgumentException | NullPointerException malformed) {
            return Optional.empty();
        }
    }
}
