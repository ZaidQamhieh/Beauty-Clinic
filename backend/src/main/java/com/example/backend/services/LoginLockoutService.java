package com.example.backend.services;

import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.LockedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class LoginLockoutService {

    private static final int MAX_ATTEMPTS = 5;
    private static final List<Duration> LOCKOUT_LADDER = List.of(
            Duration.ofMinutes(30),
            Duration.ofHours(5),
            Duration.ofDays(7)
    );

    private static final Duration MAX_LOCKOUT = Duration.ofDays(365);

    private final UserAccountRepository users;

    @Transactional(readOnly = true)
    public void assertNotLocked(String identifier) {
        users.findByEmailIgnoreCase(identifier).ifPresent(account -> {
            if (account.isLocked(Instant.now())) {
                throw new LockedException("Account temporarily locked");
            }
        });
    }

    // Own transaction: login rethrows and rolls back, discarding the count.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailure(String identifier) {
        users.lockByEmail(identifier).ifPresent(account -> {
            account.setFailedLoginCount(account.getFailedLoginCount() + 1);

            if (account.getFailedLoginCount() >= MAX_ATTEMPTS) {
                triggerLockout(account, identifier);
            }

            users.save(account);
        });
    }

    @Transactional
    public void recordSuccess(String identifier) {
        users.findByEmailIgnoreCase(identifier).ifPresent(account -> {
            account.setFailedLoginCount(0);
            account.setLockedUntil(null);
            users.save(account);
        });
    }

    private void triggerLockout(UserAccount account, String identifier) {
        Duration duration = durationForStrike(account.getLockoutStrikes());
        account.setLockedUntil(Instant.now().plus(duration));
        account.setLockoutStrikes(account.getLockoutStrikes() + 1);
        account.setFailedLoginCount(0);

        log.warn(
                "Login lockout triggered: identifier={} duration={} strike={}",
                identifier, duration, account.getLockoutStrikes()
        );
    }

    private Duration durationForStrike(int strike) {
        if (strike < LOCKOUT_LADDER.size()) {
            return LOCKOUT_LADDER.get(strike);
        }

        int lastIndex = LOCKOUT_LADDER.size() - 1;
        int extraDoublings = strike - lastIndex;

        Duration escalated = LOCKOUT_LADDER.get(lastIndex);
        for (int i = 0; i < extraDoublings; i++) {
            if (escalated.compareTo(MAX_LOCKOUT) >= 0) {
                return MAX_LOCKOUT;
            }
            escalated = escalated.multipliedBy(2);
        }

        return escalated.compareTo(MAX_LOCKOUT) > 0 ? MAX_LOCKOUT : escalated;
    }
}
