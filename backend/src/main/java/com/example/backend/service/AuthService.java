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
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.authentication.DisabledException;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserAccountRepository users;
    private final AccessTokenService accessTokens;
    private final RefreshTokenService refreshTokens;
    private final UserDetailsService userDetailsService;

    @Transactional
    public TokenResponse login(LoginRequest request) {
        /*
          Create an unauthenticated object containing the submitted
          email and plaintext password.
         */
        var credentials = UsernamePasswordAuthenticationToken
                .unauthenticated(
                        request.email().trim(),
                        request.password()
                );

        /*
          Spring calls UserAccountDetailsService and PasswordEncoder.
          Invalid credentials cause authentication to fail here.
         */
        Authentication authentication =
                authenticationManager.authenticate(credentials);

        // This is the authenticated Spring Security representation.
        UserDetails principal =
                (UserDetails) authentication.getPrincipal();

        /*
          Load the actual JPA entity because RefreshToken needs
          a relationship to UserAccount.
         */
        UserAccount user = users
                .findByEmailIgnoreCase(principal.getUsername())
                .orElseThrow(() -> new IllegalStateException(
                        "Authenticated user no longer exists"
                ));

        var accessToken = accessTokens.issue(principal);
        String refreshToken = refreshTokens.issue(user);

        // This object will later be returned as JSON by AuthController.
        return new TokenResponse(
                accessToken.value(),
                refreshToken,
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

        // Load the user's current roles and account status.
        UserDetails principal = userDetailsService.loadUserByUsername(
                rotatedToken.email()
        );

        if (!principal.isEnabled()) {
            throw new DisabledException("Account is disabled");
        }

        var accessToken = accessTokens.issue(principal);

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
