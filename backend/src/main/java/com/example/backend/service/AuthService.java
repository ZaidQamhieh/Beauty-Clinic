package com.example.backend.service;

import com.example.backend.dto.LoginRequest;
import com.example.backend.dto.RefreshTokenRequest;
import com.example.backend.dto.TokenResponse;

import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.authentication.DisabledException;

import java.util.Locale;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserAccountRepository users;
    private final AccessTokenService accessTokens;
    private final RefreshTokenService refreshTokens;
    private final UserDetailsService userDetailsService;
    private final LoginLockoutService lockouts;

    @Transactional
    public TokenResponse login(LoginRequest request) {
        String identifier = request.email().trim().toLowerCase(Locale.ROOT);

        // Reject up front if this identifier is already locked out.
        lockouts.assertNotLocked(identifier);

        /*
          Create an unauthenticated object containing the submitted
          email and plaintext password.
         */
        var credentials = UsernamePasswordAuthenticationToken
                .unauthenticated(identifier, request.password());

        /*
          Spring calls UserAccountDetailsService and PasswordEncoder.
          Invalid credentials cause authentication to fail here.
         */
        Authentication authentication;
        try {
            authentication = authenticationManager.authenticate(credentials);
        } catch (AuthenticationException failure) {
            lockouts.recordFailure(identifier);
            throw failure;
        }

        lockouts.recordSuccess(identifier);

        // This is the authenticated Spring Security representation.
        UserDetails principal =
                (UserDetails) authentication.getPrincipal();

        /*
          Load the actual JPA entity because RefreshToken needs
          a relationship to UserAccount.
         */
        UserAccount user = users
                .findByEmailIgnoreCase(principal.getUsername())
                .orElseThrow(() -> new UsernameNotFoundException(
                        "Authenticated user no longer exists"
                ));

        var refreshToken = refreshTokens.issue(user);
        var accessToken = accessTokens.issue(principal, refreshToken.sessionId());

        // This object will later be returned as JSON by AuthController.
        return new TokenResponse(
                accessToken.value(),
                refreshToken.value(),
                "Bearer",
                accessToken.expiresInSeconds()
        );
    }

    @Transactional
    public TokenResponse refresh(RefreshTokenRequest request) {
        // Validate the old refresh token and replace it.
        var rotatedToken = refreshTokens.rotate(
                request.refreshToken()
        );

        // A locked account must not be able to keep minting access tokens
        // through an existing session for the duration of the lock.
        lockouts.assertNotLocked(rotatedToken.email());

        // Load the user's current roles and account status.
        UserDetails principal = userDetailsService.loadUserByUsername(
                rotatedToken.email()
        );

        if (!principal.isEnabled()) {
            throw new DisabledException("Account is disabled");
        }

        var accessToken = accessTokens.issue(principal, rotatedToken.sessionId());

        return new TokenResponse(
                accessToken.value(),
                rotatedToken.value(),
                "Bearer",
                accessToken.expiresInSeconds()
        );
    }

    public void logout(RefreshTokenRequest request) {
        refreshTokens.logout(request.refreshToken());
    }
}
