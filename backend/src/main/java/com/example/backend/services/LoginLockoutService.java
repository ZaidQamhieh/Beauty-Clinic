package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
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

    private final UserAccountRepository users;
    private final ActivityLogService activityLogs;

    @Transactional(readOnly = true)
    public void assertNotLocked(String identifier) {
        users.findByEmailIgnoreCase(identifier).ifPresent(account -> {
            if (account.isLocked(Instant.now())) {
                throw new LockedException("Account temporarily locked");
            }
        });
    }

    // Own transaction; the rollback discards counts.
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

    // Strikes clear, or the ladder only climbs.
    @Transactional
    public void recordSuccess(String identifier) {
        users.findByEmailIgnoreCase(identifier).ifPresent(account -> {
            account.setFailedLoginCount(0);
            account.setLockedUntil(null);
            account.setLockoutStrikes(0);
            users.save(account);
        });
    }

    private void triggerLockout(UserAccount account, String identifier) {
        Duration duration = durationForStrike(account.getLockoutStrikes());
        account.setLockedUntil(Instant.now().plus(duration));
        account.setLockoutStrikes(account.getLockoutStrikes() + 1);
        account.setFailedLoginCount(0);

        activityLogs.record(
                account.getId(), null, ActivityAction.ACCOUNT_LOCKED,
                "user_account", account.getId());

        log.warn(
                "Login lockout triggered: identifier={} duration={} strike={}",
                identifier, duration, account.getLockoutStrikes()
        );
    }

    // Clamped at the last rung.
    private Duration durationForStrike(int strike) {
        return LOCKOUT_LADDER.get(Math.min(strike, LOCKOUT_LADDER.size() - 1));
    }
}
