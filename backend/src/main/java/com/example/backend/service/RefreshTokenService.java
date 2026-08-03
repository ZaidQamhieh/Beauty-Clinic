package com.example.backend.service;

import com.example.backend.security.TokenProperties;
import com.example.backend.user.UserAccount;
import lombok.RequiredArgsConstructor;

import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import com.example.backend.entity.RefreshToken;
import com.example.backend.repository.RefreshTokenRepository;

@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    // Generates values that cannot be practically guessed.
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokens;
    private final TokenProperties properties;

    @Transactional
    public IssuedRefreshToken issue(UserAccount user) {
        // This raw value is sent to the client but never stored.
        String rawToken = generateToken();

        // Only the SHA-256 hash is saved in PostgreSQL.
        String tokenHash = hash(rawToken);

        Instant expiresAt = Instant.now()
                .plus(properties.refreshTtl());

        RefreshToken saved = refreshTokens.save(
                new RefreshToken(user, tokenHash, expiresAt)
        );

        return new IssuedRefreshToken(saved.getId(), rawToken);
    }

    @Transactional
    public RotatedRefreshToken rotate(String rawToken) {
        String tokenHash = hash(rawToken);

        RefreshToken currentToken = refreshTokens
                .findByTokenHash(tokenHash)
                .orElseThrow(() -> new BadCredentialsException(
                        "Invalid refresh token"
                ));

        if (currentToken.isExpired(Instant.now())) {
            throw new BadCredentialsException(
                    "Invalid refresh token"
            );
        }

        UserAccount user = currentToken.getUser();

        // A refresh token can only be used once; this also revokes its access token.
        refreshTokens.delete(currentToken);

        IssuedRefreshToken newToken = issue(user);

        return new RotatedRefreshToken(
                newToken.sessionId(),
                user.getEmail(),
                newToken.value()
        );
    }

    private String generateToken() {
        byte[] randomBytes = new byte[32];
        SECURE_RANDOM.nextBytes(randomBytes);

        /*
          URL-safe Base64 avoids characters such as "/" and "+"
          that can be awkward when tokens are transmitted.
         */
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(randomBytes);
    }

    private String hash(String rawToken) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(rawToken.getBytes(StandardCharsets.UTF_8));

            // Convert the hash bytes into a 64-character database string.
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "SHA-256 is unavailable",
                    exception
            );
        }
    }

    @Transactional
    public void logout(String rawToken) {
        String tokenHash = hash(rawToken);

        refreshTokens.findByTokenHash(tokenHash)
                .ifPresent(refreshTokens::delete);
    }

    public record IssuedRefreshToken(
        UUID sessionId,
        String value
    ) {
    }

    public record RotatedRefreshToken(
        UUID sessionId,
        String email,
        String value
    ) {
    }
}

