package com.example.backend.security;

import com.example.backend.services.AccessTokenService;
import com.example.backend.services.ActivityLogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.security.authorization.event.AuthorizationDeniedEvent;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
class AccessDeniedListener {

    private final ActivityLogService activityLogs;

    @EventListener
    void onDenied(AuthorizationDeniedEvent<?> event) {
        Authentication authentication =
                event.getAuthentication().get();

        activityLogs.recordPermissionDenied(
                userId(authentication)
        );

        log.warn(
                "Access denied: principal={}",
                authentication.getName()
        );
    }

    private Optional<UUID> userId(
            Authentication authentication
    ) {
        Object principal = authentication.getPrincipal();

        if (principal instanceof UserAccountDetails user) {
            return Optional.of(user.getUserId());
        }

        if (!(principal instanceof Jwt token)) {
            return Optional.empty();
        }

        String claim = token.getClaimAsString(
                AccessTokenService.USER_ID_CLAIM
        );

        try {
            return Optional.of(UUID.fromString(claim));
        } catch (
                IllegalArgumentException |
                NullPointerException invalidClaim
        ) {
            return Optional.empty();
        }
    }
}
