package com.example.backend.auth;

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

@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    // Generates values that cannot be practically guessed.
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokens;
    private final TokenProperties properties;

    @Transactional
    public String issue(UserAccount user) {
        // This raw value is sent to the client but never stored.
        String rawToken = generateToken();

        // Only the SHA-256 hash is saved in PostgreSQL.
        String tokenHash = hash(rawToken);

        Instant expiresAt = Instant.now()
                .plus(properties.refreshTtl());

        refreshTokens.save(
                new RefreshToken(user, tokenHash, expiresAt)
        );

        return rawToken;
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

        // A refresh token can only be successfully used once.
        refreshTokens.delete(currentToken);

        String newToken = issue(user);

        return new RotatedRefreshToken(
                user.getEmail(),
                newToken
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

    public record RotatedRefreshToken(
        String email,
        String value
    ) {
    }
} 

