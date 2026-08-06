package com.example.backend.security;

import com.example.backend.services.AccessTokenService;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

// Caller's account id, read from the token's uid claim.
@Component("currentUser")
public class CurrentUser {

    public Optional<UUID> id() {
        Authentication authentication =
                SecurityContextHolder.getContext().getAuthentication();

        if (authentication == null
                || !(authentication.getPrincipal() instanceof Jwt token)) {
            return Optional.empty();
        }

        String claim = token.getClaimAsString(AccessTokenService.USER_ID_CLAIM);

        try {
            return Optional.of(UUID.fromString(claim));
        } catch (IllegalArgumentException | NullPointerException absentOrMalformed) {
            return Optional.empty();
        }
    }

    public UUID requireId() {
        return id().orElseThrow(() -> new IllegalStateException(
                "No authenticated user id on the current request"
        ));
    }

    public boolean is(UUID userId) {
        return id().filter(userId::equals).isPresent();
    }

    public boolean hasRole(Role role) {
        Authentication authentication =
                SecurityContextHolder.getContext().getAuthentication();

        return authentication != null
                && authentication.getAuthorities().contains(role.authority());
    }
}
