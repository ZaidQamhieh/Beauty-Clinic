package com.example.backend.security;

import java.util.Base64;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

@Configuration
// Activates and validates values under app.auth.tokens.
@EnableConfigurationProperties(TokenProperties.class) 
class JwtConfig {

    @Bean
    SecretKey jwSecretKey(TokenProperties properties) {
        byte[] secret;

        try {
                // AUTH_JWT_SECRET is Base64 so the raw key bytes survive a .env file.
            secret = Base64.getDecoder().decode(properties.secret());
        } catch(IllegalArgumentException | NullPointerException exc) {
            throw new IllegalStateException(
                "AUTH_JWT_SECRET must be valid Base64",
                exc
            );
        }
        
        // HS256 requires a key containing at least 256 bits (32 bytes).
        if (secret.length < 32) {
            throw new IllegalStateException(
                "AUTH_JWT_SECRET must contain at least 32 bytes"
            );
        }
        
        return new SecretKeySpec(secret, "HmacSHA256");
    }

    @Bean
    JwtEncoder jwtEncoder(SecretKey secretKey) {

        // Signs outgoing access tokens.
        return NimbusJwtEncoder.withSecretKey(secretKey)
                .algorithm(MacAlgorithm.HS256)
                .build();
    }

    @Bean
    JwtDecoder jwtDecoder(
            SecretKey secretKey,
            TokenProperties properties,
            SessionTokenValidator sessionTokenValidator
    ) {
        // Same key verifies incoming tokens: HS256 is symmetric.
        NimbusJwtDecoder decoder = NimbusJwtDecoder
                .withSecretKey(secretKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();

        // Validate issuer/expiration, then that the session isn't revoked.
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(properties.issuer()),
                sessionTokenValidator
        ));

        return decoder;
    }
}
