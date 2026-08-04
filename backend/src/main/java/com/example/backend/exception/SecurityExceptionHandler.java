package com.example.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.authorization.AuthorizationDeniedException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
class SecurityExceptionHandler {

    @ExceptionHandler(AuthorizationDeniedException.class)
    ProblemDetail onAuthorizationDenied(AuthorizationDeniedException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.FORBIDDEN);
        problem.setTitle("Access Denied");
        problem.setDetail("You do not have permission to access this resource");
        return problem;
    }

    // Covers the account-vanished-mid-request races in AuthService: the
    // authenticated user disappearing between authenticate() and the
    // follow-up lookup in login(), and a refresh token outliving the
    // account it belongs to.
    @ExceptionHandler(UsernameNotFoundException.class)
    ProblemDetail onUsernameNotFound(UsernameNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        problem.setTitle("Authentication Failed");
        problem.setDetail("Invalid credentials");
        return problem;
    }
}