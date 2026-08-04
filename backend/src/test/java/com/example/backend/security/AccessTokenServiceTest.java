package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ActiveProfiles;

import com.example.backend.entity.RefreshToken;
import com.example.backend.repository.RefreshTokenRepository;
import com.example.backend.service.AccessTokenService;
import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountRepository;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class AccessTokenServiceTest extends AbstractIntegrationTest {

    @Autowired
    private AccessTokenService accessTokens;

    @Autowired
    private JwtDecoder jwtDecoder;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private RefreshTokenRepository refreshTokens;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void issuesSignedTokenWithExpectedClaims() {
        // Create an authenticated test user without using the database.
        var user = User.withUsername("doctor@example.com")
                .password("unused")
                .authorities("ROLE_DOCTOR", "ROLE_ADMIN")
                .build();

        // The token's "sid" claim must point at a real session for the
        // decoder's SessionTokenValidator to accept it.
        UserAccount account = users.save(new UserAccount(
                "doctor@example.com",
                passwordEncoder.encode("unused"),
                Set.of(com.example.backend.security.Role.DOCTOR)
        ));
        RefreshToken session = refreshTokens.save(new RefreshToken(
                account, "unused-hash", Instant.now().plus(7, ChronoUnit.DAYS)
        ));

        // Generate a real signed access token.
        var issuedToken = accessTokens.issue(user, session.getId());

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
        assertThat(decodedToken.getClaimAsString(AccessTokenService.SESSION_CLAIM))
                .isEqualTo(session.getId().toString());

        // Authorities are sorted before being placed in the token.
        assertThat(
                decodedToken.getClaimAsStringList(
                        AccessTokenService.AUTHORITIES_CLAIM
                )
        ).containsExactly("ROLE_ADMIN", "ROLE_DOCTOR");
    }
}