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

// Ranked ahead of FallbackExceptionHandler, which would otherwise tie with it.
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

    // Covers the account vanishing mid-request, and a token outliving its account.
    @ExceptionHandler(UsernameNotFoundException.class)
    ProblemDetail onUsernameNotFound(UsernameNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail("Invalid credentials");
        return problem;
    }

    // Every other authenticate() failure, so all share one shape, not a bare 401.
    @ExceptionHandler(AuthenticationException.class)
    ProblemDetail onAuthenticationFailed(AuthenticationException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail("Invalid credentials");
        return problem;
    }
}