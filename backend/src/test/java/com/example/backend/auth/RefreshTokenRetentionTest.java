package com.example.backend.auth;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.RefreshToken;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.RefreshTokenRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.RefreshTokenRetention;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

// Dead rows leave; live sessions stay.
@SpringBootTest
@ActiveProfiles("test")
class RefreshTokenRetentionTest extends AbstractIntegrationTest {

    private static final String EMAIL = "sweep@example.com";

    @Autowired
    private RefreshTokenRetention retention;

    @Autowired
    private RefreshTokenRepository refreshTokens;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private EntityManager entityManager;

    @AfterEach
    void removeTestAccount() {
        users.findByEmailIgnoreCase(EMAIL).ifPresent(users::delete);
    }

    @Test
    void theSweepRemovesExpiredAndSoftDeletedRowsOnly() {
        UserAccount account = users.saveAndFlush(new UserAccount(
                EMAIL, passwordEncoder.encode("password"), "Test", "User", Role.PATIENT));

        UUID live = save(account, Instant.now().plus(Duration.ofDays(15))).getId();
        UUID expired = save(account, Instant.now().minus(Duration.ofDays(1))).getId();
        UUID softDeleted = save(account, Instant.now().plus(Duration.ofDays(15))).getId();

        refreshTokens.deleteById(softDeleted);
        refreshTokens.flush();

        retention.purge();
        entityManager.clear();

        assertThat(rowExists(live)).isTrue();
        assertThat(rowExists(expired)).isFalse();
        assertThat(rowExists(softDeleted)).isFalse();
    }

    private RefreshToken save(UserAccount account, Instant expiresAt) {
        return refreshTokens.saveAndFlush(
                new RefreshToken(account, "hash-" + UUID.randomUUID(), expiresAt));
    }

    // Counts the raw row, soft-delete flag included.
    private boolean rowExists(UUID id) {
        Number count = (Number) entityManager
                .createNativeQuery("select count(*) from refresh_token where id = :id")
                .setParameter("id", id)
                .getSingleResult();
        return count.intValue() > 0;
    }

}
