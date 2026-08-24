package com.example.backend.exception;

import org.springframework.security.authentication.LockedException;

import java.time.Instant;

// Distinct from a wrong password.
public class AccountLockedException extends LockedException {

    private final Instant lockedUntil;

    public AccountLockedException(Instant lockedUntil) {
        super("Account temporarily locked");
        this.lockedUntil = lockedUntil;
    }

    public Instant getLockedUntil() {
        return lockedUntil;
    }
}
