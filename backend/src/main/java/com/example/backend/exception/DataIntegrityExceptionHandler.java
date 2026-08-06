package com.example.backend.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

// Races lose at the database; answer 409, not 500. Ranked ahead of the fallback.
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE - 10)
@Slf4j
class DataIntegrityExceptionHandler {

    @ExceptionHandler(DataIntegrityViolationException.class)
    ProblemDetail onDataIntegrityViolation(DataIntegrityViolationException ex) {
        // Logged whole: a violation the application should have caught is a bug.
        log.warn("Database rejected a write as conflicting", ex);

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        problem.setTitle("Conflict");
        problem.setDetail("That change conflicts with data already stored");
        return problem;
    }
}
