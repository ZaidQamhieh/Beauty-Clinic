package com.example.backend.security;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ActiveProfiles;

import com.example.backend.service.AccessTokenService;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class AccessTokenServiceTest {

    @Autowired
    private AccessTokenService accessTokens;

    @Autowired
    private JwtDecoder jwtDecoder;

    @Test
    void issuesSignedTokenWithExpectedClaims() {
        // Create an authenticated test user without using the database.
        var user = User.withUsername("doctor@example.com")
                .password("unused")
                .authorities("ROLE_DOCTOR", "ROLE_ADMIN")
                .build();

        // Generate a real signed access token.
        var issuedToken = accessTokens.issue(user);

        // Decode it using the same validation used for incoming requests.
        Jwt decodedToken = jwtDecoder.decode(issuedToken.value());

        assertThat(issuedToken.expiresInSeconds()).isEqualTo(900);
        assertThat(decodedToken.getIssuer().toString())
                .isEqualTo("https://beauty-clinic.test");
        assertThat(decodedToken.getSubject())
                .isEqualTo("doctor@example.com");
        assertThat(decodedToken.getId()).isNotBlank();
        assertThat(decodedToken.getIssuedAt()).isNotNull();
        assertThat(decodedToken.getExpiresAt())
                .isAfter(decodedToken.getIssuedAt());

        // Authorities are sorted before being placed in the token.
        assertThat(
                decodedToken.getClaimAsStringList(
                        AccessTokenService.AUTHORITIES_CLAIM
                )
        ).containsExactly("ROLE_ADMIN", "ROLE_DOCTOR");
    }
}