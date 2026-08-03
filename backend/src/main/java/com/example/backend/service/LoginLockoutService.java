package com.example.backend.service;

import com.example.backend.entity.LoginLockout;
import com.example.backend.repository.LoginLockoutRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.LockedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/*
  Escalating lockout ladder: 5 fails locks for 30 minutes, a repeat
  lockout for 5 hours, a third for a week, then each further lockout
  doubles the last duration. Strikes never reset on their own.

  Lockout events are only logged (SLF4J) for now, not written to the
  activity log — that feature (LOG-1) doesn't exist yet.
 */
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

    private final LoginLockoutRepository lockouts;

    @Transactional
    public void assertNotLocked(String identifier) {
        lockouts.findByIdentifier(identifier).ifPresent(lockout -> {
            if (lockout.isLocked(Instant.now())) {
                throw new LockedException("Account temporarily locked");
            }
        });
    }

    @Transactional
    public void recordFailure(String identifier) {
        LoginLockout lockout = lockouts.findByIdentifier(identifier)
                .orElseGet(() -> new LoginLockout(identifier));

        lockout.setFailedAttempts(lockout.getFailedAttempts() + 1);

        if (lockout.getFailedAttempts() >= MAX_ATTEMPTS) {
            Duration duration = durationForStrike(lockout.getLockoutStrikes());
            lockout.setLockedUntil(Instant.now().plus(duration));
            lockout.setLockoutStrikes(lockout.getLockoutStrikes() + 1);
            lockout.setFailedAttempts(0);

            log.warn(
                    "Login lockout triggered: identifier={} duration={} strike={}",
                    identifier, duration, lockout.getLockoutStrikes()
            );
        }

        lockouts.save(lockout);
    }

    @Transactional
    public void recordSuccess(String identifier) {
        lockouts.findByIdentifier(identifier).ifPresent(lockout -> {
            lockout.setFailedAttempts(0);
            lockout.setLockedUntil(null);
            lockouts.save(lockout);
        });
    }

    private Duration durationForStrike(int strike) {
        if (strike < LOCKOUT_LADDER.size()) {
            return LOCKOUT_LADDER.get(strike);
        }

        int lastIndex = LOCKOUT_LADDER.size() - 1;
        int extraDoublings = strike - lastIndex;
        return LOCKOUT_LADDER.get(lastIndex).multipliedBy(1L << extraDoublings);
    }
}
