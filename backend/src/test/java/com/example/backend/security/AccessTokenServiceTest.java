package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.ActiveProfiles;

import com.example.backend.entities.RefreshToken;
import com.example.backend.repositories.RefreshTokenRepository;
import com.example.backend.services.AccessTokenService;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

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
        UserAccount account = users.save(new UserAccount(
                "doctor@example.com",
                passwordEncoder.encode("unused"),
                "Test",
                "User",
                Role.DOCTOR
        ));
        RefreshToken session = refreshTokens.save(new RefreshToken(
                account, "unused-hash", Instant.now().plus(7, ChronoUnit.DAYS)
        ));

        var issuedToken = accessTokens.issue(
                UserAccountDetails.of(account), session.getId()
        );

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

        assertThat(decodedToken.getClaimAsString(AccessTokenService.USER_ID_CLAIM))
                .isEqualTo(account.getId().toString());

        assertThat(
                decodedToken.getClaimAsStringList(
                        AccessTokenService.AUTHORITIES_CLAIM
                )
        ).containsExactly("ROLE_DOCTOR");
    }
}