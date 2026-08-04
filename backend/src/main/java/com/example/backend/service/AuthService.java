package com.example.backend.service;

import com.example.backend.dto.LoginRequest;
import com.example.backend.dto.RefreshTokenRequest;
import com.example.backend.dto.TokenResponse;

import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountDetails;
import com.example.backend.user.UserAccountDetailsService;
import com.example.backend.user.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
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
    private final UserAccountDetailsService userDetailsService;
    private final LoginLockoutService lockouts;

    @Transactional
    public TokenResponse login(LoginRequest request) {
        String identifier = request.email().trim().toLowerCase(Locale.ROOT);

        lockouts.assertNotLocked(identifier);

        var credentials = UsernamePasswordAuthenticationToken
                .unauthenticated(identifier, request.password());

        Authentication authentication;
        try {
            authentication = authenticationManager.authenticate(credentials);
        } catch (AuthenticationException failure) {
            lockouts.recordFailure(identifier);
            throw failure;
        }

        lockouts.recordSuccess(identifier);

        UserAccountDetails principal =
                (UserAccountDetails) authentication.getPrincipal();

        UserAccount user = users
                .findById(principal.getUserId())
                .orElseThrow(() -> new UsernameNotFoundException(
                        "Authenticated user no longer exists"
                ));

        var refreshToken = refreshTokens.issue(user);
        var accessToken = accessTokens.issue(principal, refreshToken.sessionId());

        return new TokenResponse(
                accessToken.value(),
                refreshToken.value(),
                "Bearer",
                accessToken.expiresInSeconds()
        );
    }

    @Transactional
    public TokenResponse refresh(RefreshTokenRequest request) {
        var rotatedToken = refreshTokens.rotate(
                request.refreshToken()
        );

        lockouts.assertNotLocked(rotatedToken.email());

        UserAccountDetails principal = userDetailsService.loadUserByUsername(
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
