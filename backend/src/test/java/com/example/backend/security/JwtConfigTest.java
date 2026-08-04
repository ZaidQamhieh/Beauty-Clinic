package com.example.backend.security;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtConfigTest {

    private final JwtConfig jwtConfig = new JwtConfig();

    @Test
    void rejectsNonBase64Secret() {
        TokenProperties properties = new TokenProperties(
                "https://beauty-clinic.test",
                Duration.ofMinutes(15),
                Duration.ofDays(7),
                "not-valid-base64!!"
        );

        assertThatThrownBy(() -> jwtConfig.jwSecretKey(properties))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("must be valid Base64");
    }

    @Test
    void rejectsSecretShorterThan32Bytes() {
        String tooShort = Base64.getEncoder().encodeToString(new byte[16]);
        TokenProperties properties = new TokenProperties(
                "https://beauty-clinic.test",
                Duration.ofMinutes(15),
                Duration.ofDays(7),
                tooShort
        );

        assertThatThrownBy(() -> jwtConfig.jwSecretKey(properties))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 32 bytes");
    }
}
