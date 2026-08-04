package com.example.backend.service;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entity.LoginLockout;
import com.example.backend.repository.LoginLockoutRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.LockedException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class LoginLockoutServiceTest extends AbstractIntegrationTest {

    @Autowired
    private LoginLockoutService lockouts;

    @Autowired
    private LoginLockoutRepository repository;

    @Test
    void locksAfterFiveFailuresThenRejectsFurtherAttempts() {
        String identifier = "brute-force@example.com";

        for (int i = 0; i < 5; i++) {
            lockouts.assertNotLocked(identifier);
            lockouts.recordFailure(identifier);
        }

        assertThatThrownBy(() -> lockouts.assertNotLocked(identifier))
                .isInstanceOf(LockedException.class);
    }

    @Test
    void successBeforeFifthFailureDoesNotTriggerLock() {
        String identifier = "resets-on-success@example.com";

        failNTimes(identifier, 4);

        // A success before the 5th failure should not trigger a lock.
        lockouts.recordSuccess(identifier);
        lockouts.assertNotLocked(identifier);
    }

    @Test
    void secondLockoutEscalatesFrom30MinutesTo5Hours() {
        String identifier = "repeat-offender@example.com";

        failNTimes(identifier, 5);
        LoginLockout firstLockout = repository.findByIdentifier(identifier).orElseThrow();
        assertThat(firstLockout.getLockoutStrikes()).isEqualTo(1);
        assertLockedForAbout(firstLockout, Duration.ofMinutes(30));

        failNTimes(identifier, 5);
        LoginLockout secondLockout = repository.findByIdentifier(identifier).orElseThrow();
        assertThat(secondLockout.getLockoutStrikes()).isEqualTo(2);
        assertLockedForAbout(secondLockout, Duration.ofHours(5));
    }

    private void failNTimes(String identifier, int n) {
        for (int i = 0; i < n; i++) {
            lockouts.recordFailure(identifier);
        }
    }

    private void assertLockedForAbout(LoginLockout lockout, Duration expected) {
        assertThat(Duration.between(Instant.now(), lockout.getLockedUntil()))
                .isCloseTo(expected, Duration.ofMinutes(1));
    }
}
