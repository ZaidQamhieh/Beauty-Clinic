package com.example.backend.exception;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.authorization.AuthorizationDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Duration;
import java.time.Instant;

// Ranked ahead of FallbackExceptionHandler.
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE - 10)
class SecurityExceptionHandler {

    @ExceptionHandler(AuthorizationDeniedException.class)
    ProblemDetail onAuthorizationDenied(AuthorizationDeniedException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.FORBIDDEN);
        problem.setTitle("Access Denied");
        problem.setDetail("You do not have permission to access this resource");
        return problem;
    }

    // Ahead of the generic AuthenticationException handler below.
    @ExceptionHandler(AccountLockedException.class)
    ProblemDetail onAccountLocked(AccountLockedException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.LOCKED);
        problem.setTitle("Account Locked");
        problem.setDetail(
                "Too many failed sign-in attempts. Try again in "
                        + minutesUntil(ex.getLockedUntil()) + ".");
        return problem;
    }

    private String minutesUntil(Instant target) {
        long minutes = Duration.between(Instant.now(), target).toMinutes();
        if (minutes <= 1) {
            return "a minute";
        }
        if (minutes < 60) {
            return minutes + " minutes";
        }
        long hours = minutes / 60;
        if (hours < 24) {
            return hours + (hours == 1 ? " hour" : " hours");
        }
        long days = hours / 24;
        return days + (days == 1 ? " day" : " days");
    }

    // Ahead of the generic AuthenticationException handler below.
    @ExceptionHandler(InvalidCredentialsException.class)
    ProblemDetail onInvalidCredentials(InvalidCredentialsException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail(remainingAttemptsDetail(ex.getRemainingAttempts()));
        return problem;
    }

    private String remainingAttemptsDetail(Integer remaining) {
        if (remaining == null) {
            return "Invalid credentials";
        }
        String noun = remaining == 1 ? "attempt" : "attempts";
        return "Invalid credentials. " + remaining + " " + noun + " remaining before lockout.";
    }

    // Covers a vanished account or stale token.
    @ExceptionHandler(UsernameNotFoundException.class)
    ProblemDetail onUsernameNotFound(UsernameNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail("Invalid credentials");
        return problem;
    }

    // Every other authenticate() failure, same shape.
    @ExceptionHandler(AuthenticationException.class)
    ProblemDetail onAuthenticationFailed(AuthenticationException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail("Invalid credentials");
        return problem;
    }
}