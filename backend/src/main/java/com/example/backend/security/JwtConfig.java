package com.example.backend.security;

import java.util.Base64;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

@Configuration
// Activates and validates values under app.auth.tokens.
@EnableConfigurationProperties(TokenProperties.class) 
class JwtConfig {

    @Bean // Spring will use method to create and configure the object
    SecretKey jwSecretKey(TokenProperties properties) {
        byte[] secret;

        try {
            // Convert the Base64 text from .env back into secure key bytes
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
        
        // Wrap the bytes as a key usable by the HMAC-SHA256 algorithm.
        return new SecretKeySpec(secret, "HmacSHA256");
    }

    @Bean
    JwtEncoder jwtEncoder(SecretKey secretKey) {
        // Nimbus is Spring Security's JWT implementation.
        // The encoder creates and signs outgoing access tokens.
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
        // The decoder verifies incoming token signatures using the same key.
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
