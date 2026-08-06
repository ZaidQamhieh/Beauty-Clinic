package com.example.backend.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

// Keeps unexpected failures on problem+json, not the container's /error. Ordered last.
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE)
@Slf4j
class FallbackExceptionHandler {

    @ExceptionHandler(Exception.class)
    ProblemDetail onUnexpected(Exception ex) {
        // Reaching here is a bug, so log it whole; the response says nothing.
        log.error("Unhandled exception", ex);

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        problem.setTitle("Internal Server Error");
        problem.setDetail("The request could not be completed");
        return problem;
    }
}
