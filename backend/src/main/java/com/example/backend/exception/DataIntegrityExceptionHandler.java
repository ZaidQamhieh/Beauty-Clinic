package com.example.backend.exception;

import lombok.extern.slf4j.Slf4j;
import org.hibernate.exception.ConstraintViolationException;
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
        // Name only: Postgres puts the clashing values in the message, and those are patient data.
        log.warn("Database rejected a write as conflicting: {}", constraintOf(ex));

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        problem.setTitle("Conflict");
        problem.setDetail("That change conflicts with data already stored");
        return problem;
    }

    private String constraintOf(DataIntegrityViolationException ex) {
        if (ex.getCause() instanceof ConstraintViolationException violation
                && violation.getConstraintName() != null) {
            return violation.getConstraintName();
        }
        return "unnamed constraint";
    }
}
