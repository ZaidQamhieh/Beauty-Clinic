package com.example.backend.service;

import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.LockedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/*
  Escalating lockout ladder: 5 fails locks for 30 minutes, a repeat
  lockout for 5 hours, a third for a week, then each further lockout
  doubles the last duration, capped at MAX_LOCKOUT. Strikes never reset
  on their own.

  State lives on user_account, so only real accounts are throttled.
  Attempts against an unknown email are not counted anywhere - rate
  limiting those belongs at the gateway, not in the database.

  Lockout events are only logged (SLF4J) for now, not written to the
  activity log - that feature (LOG-1) doesn't exist yet.
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

    // Ceiling for the doubling tail, so a very high strike count can't
    // overflow Duration arithmetic.
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

    /*
      REQUIRES_NEW matters: the caller (AuthService.login) is transactional
      and rethrows the AuthenticationException that brought us here, which
      would roll its transaction back. Counting the failure in a separate
      transaction is what makes the increment survive the rejected login.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailure(String identifier) {
        users.findByEmailIgnoreCaseForUpdate(identifier).ifPresent(account -> {
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

        // Doubled step by step rather than shifted by extraDoublings, so a
        // large strike count hits the cap instead of overflowing.
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
