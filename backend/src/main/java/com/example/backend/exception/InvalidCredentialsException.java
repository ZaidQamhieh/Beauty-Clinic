package com.example.backend.exception;

import org.springframework.security.authentication.BadCredentialsException;

// Null remainingAttempts means the account is unknown.
public class InvalidCredentialsException extends BadCredentialsException {

    private final Integer remainingAttempts;

    public InvalidCredentialsException(Integer remainingAttempts) {
        super("Invalid credentials");
        this.remainingAttempts = remainingAttempts;
    }

    public Integer getRemainingAttempts() {
        return remainingAttempts;
    }
}
