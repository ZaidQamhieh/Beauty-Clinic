package com.example.backend.security;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.RefreshToken;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.RefreshTokenRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.services.AccessTokenService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import javax.crypto.spec.SecretKeySpec;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// A client-shaped token must not buy anything.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TokenTamperingTest extends AbstractIntegrationTest {

    private static final String ISSUER = "https://beauty-clinic.test";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtEncoder jwtEncoder;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private RefreshTokenRepository refreshTokens;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private final List<String> createdEmails = new ArrayList<>();

    @AfterEach
    void removeTestAccounts() {
        createdEmails.forEach(email ->
                users.findByEmailIgnoreCase(email).ifPresent(users::delete));
        createdEmails.clear();
    }

    @Test
    void aPatientCannotMintItselfTheAdminRole() throws Exception {
        Fixture fixture = fixture("escalate@example.com", Role.PATIENT);

        String token = sign(claims(fixture, List.of("ROLE_ADMIN")));

        mockMvc.perform(get("/test/meta/admin")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void addingARoleAlongsideTheRealOneIsAlsoRejected() throws Exception {
        Fixture fixture = fixture("escalate-both@example.com", Role.PATIENT);

        String token = sign(claims(fixture, List.of("ROLE_PATIENT", "ROLE_ADMIN")));

        mockMvc.perform(get("/test/meta/admin")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aTokenSignedWithAnotherKeyIsRejected() throws Exception {
        Fixture fixture = fixture("forged@example.com", Role.PATIENT);

        byte[] otherKey = new byte[32];
        java.util.Arrays.fill(otherKey, (byte) 7);
        JwtEncoder forger = NimbusJwtEncoder
                .withSecretKey(new SecretKeySpec(otherKey, "HmacSHA256"))
                .algorithm(MacAlgorithm.HS256)
                .build();

        String token = forger.encode(JwtEncoderParameters.from(
                header(), claims(fixture, List.of("ROLE_PATIENT")))).getTokenValue();

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void anExpiredTokenIsRejected() throws Exception {
        Fixture fixture = fixture("expired@example.com", Role.PATIENT);

        Instant past = Instant.now().minus(Duration.ofHours(2));
        String token = sign(JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(fixture.account().getEmail())
                .issuedAt(past)
                .expiresAt(past.plusSeconds(60))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_PATIENT"))
                .claim(AccessTokenService.SESSION_CLAIM, fixture.sessionId().toString())
                .claim(AccessTokenService.USER_ID_CLAIM, fixture.account().getId().toString())
                .build());

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aTokenFromAnotherIssuerIsRejected() throws Exception {
        Fixture fixture = fixture("issuer@example.com", Role.PATIENT);

        String token = sign(JwtClaimsSet.builder()
                .issuer("https://attacker.example")
                .subject(fixture.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_PATIENT"))
                .claim(AccessTokenService.SESSION_CLAIM, fixture.sessionId().toString())
                .claim(AccessTokenService.USER_ID_CLAIM, fixture.account().getId().toString())
                .build());

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void borrowingAnotherAccountsSessionIdIsRejected() throws Exception {
        Fixture mine = fixture("borrower@example.com", Role.PATIENT);
        Fixture theirs = fixture("victim@example.com", Role.ADMIN);

        String token = sign(JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(mine.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_PATIENT"))
                .claim(AccessTokenService.SESSION_CLAIM, theirs.sessionId().toString())
                .claim(AccessTokenService.USER_ID_CLAIM, mine.account().getId().toString())
                .build());

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aTokenWithoutASessionClaimIsRejected() throws Exception {
        Fixture fixture = fixture("no-session@example.com", Role.PATIENT);

        String token = sign(JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(fixture.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_PATIENT"))
                .claim(AccessTokenService.USER_ID_CLAIM, fixture.account().getId().toString())
                .build());

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aTokenWithoutAUserClaimIsRejected() throws Exception {
        Fixture fixture = fixture("no-user@example.com", Role.PATIENT);

        String token = sign(JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(fixture.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_PATIENT"))
                .claim(AccessTokenService.SESSION_CLAIM, fixture.sessionId().toString())
                .build());

        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void swappingTheUserClaimToAnotherAccountIsRejected() throws Exception {
        Fixture mine = fixture("swapper@example.com", Role.PATIENT);
        Fixture theirs = fixture("swapped@example.com", Role.ADMIN);

        String token = sign(JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(mine.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, List.of("ROLE_ADMIN"))
                .claim(AccessTokenService.SESSION_CLAIM, mine.sessionId().toString())
                .claim(AccessTokenService.USER_ID_CLAIM, theirs.account().getId().toString())
                .build());

        mockMvc.perform(get("/test/meta/admin")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    private String sign(JwtClaimsSet claims) {
        return jwtEncoder.encode(JwtEncoderParameters.from(header(), claims)).getTokenValue();
    }

    private JwsHeader header() {
        return JwsHeader.with(MacAlgorithm.HS256).type("JWT").build();
    }

    private JwtClaimsSet claims(Fixture fixture, List<String> authorities) {
        return JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(fixture.account().getEmail())
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(900))
                .id(UUID.randomUUID().toString())
                .claim(AccessTokenService.AUTHORITIES_CLAIM, authorities)
                .claim(AccessTokenService.SESSION_CLAIM, fixture.sessionId().toString())
                .claim(AccessTokenService.USER_ID_CLAIM, fixture.account().getId().toString())
                .build();
    }

    private Fixture fixture(String email, Role role) {
        createdEmails.add(email);
        UserAccount account = users.saveAndFlush(new UserAccount(
                email, passwordEncoder.encode("password"), "Test", "User", role));

        RefreshToken session = refreshTokens.saveAndFlush(new RefreshToken(
                account, "hash-" + UUID.randomUUID(), Instant.now().plus(Duration.ofHours(12))));

        return new Fixture(account, session.getId());
    }

    private record Fixture(UserAccount account, UUID sessionId) {
    }
}
