package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.UserAccount;
import com.example.backend.exception.AccountLockedException;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

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
                throw new AccountLockedException(account.getLockedUntil());
            }
        });
    }

    // Own transaction; the rollback discards counts.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public FailureOutcome recordFailure(String identifier) {
        return users.lockByEmail(identifier)
                .map(account -> applyFailure(account, identifier))
                .orElse(FailureOutcome.UNKNOWN_ACCOUNT);
    }

    private FailureOutcome applyFailure(UserAccount account, String identifier) {
        account.setFailedLoginCount(account.getFailedLoginCount() + 1);

        Instant lockedUntil = null;
        if (account.getFailedLoginCount() >= MAX_ATTEMPTS) {
            lockedUntil = triggerLockout(account, identifier);
        }

        users.save(account);
        int remaining = Math.max(0, MAX_ATTEMPTS - account.getFailedLoginCount());
        return new FailureOutcome(remaining, lockedUntil);
    }

    // Strikes clear, or the ladder only climbs.
    @Transactional
    public Optional<UserAccount> recordSuccess(String identifier) {
        return users.findByEmailIgnoreCase(identifier).map(account -> {
            account.setFailedLoginCount(0);
            account.setLockedUntil(null);
            account.setLockoutStrikes(0);
            return users.save(account);
        });
    }

    private Instant triggerLockout(UserAccount account, String identifier) {
        Duration duration = durationForStrike(account.getLockoutStrikes());
        Instant lockedUntil = Instant.now().plus(duration);
        account.setLockedUntil(lockedUntil);
        account.setLockoutStrikes(account.getLockoutStrikes() + 1);
        account.setFailedLoginCount(0);

        activityLogs.record(
                account.getId(), null, ActivityAction.ACCOUNT_LOCKED,
                "user_account", account.getId());

        log.warn(
                "Login lockout triggered: identifier={} duration={} strike={}",
                identifier, duration, account.getLockoutStrikes()
        );

        return lockedUntil;
    }

    // Clamped at the last rung.
    private Duration durationForStrike(int strike) {
        return LOCKOUT_LADDER.get(Math.min(strike, LOCKOUT_LADDER.size() - 1));
    }

    // Null means unknown account, or not locked.
    public record FailureOutcome(Integer remainingAttempts, Instant lockedUntil) {
        static final FailureOutcome UNKNOWN_ACCOUNT = new FailureOutcome(null, null);
    }
}
