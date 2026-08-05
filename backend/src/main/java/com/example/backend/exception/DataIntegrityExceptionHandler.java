package com.example.backend.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

// The schema enforces rules the application also checks: the double-booking
// exclusion constraint and the live-row unique indexes. Two requests racing for
// the same slot both pass their check and one loses at the database, which is
// the constraint working, not a fault - so it answers 409 like the check would
// have, rather than the 500 an unhandled violation would produce.
@RestControllerAdvice
@Slf4j
class DataIntegrityExceptionHandler {

    @ExceptionHandler(DataIntegrityViolationException.class)
    ProblemDetail onDataIntegrityViolation(DataIntegrityViolationException ex) {
        // Logged in full: a violation the application should have caught first is
        // a bug, and the response deliberately says nothing about which row.
        log.warn("Database rejected a write as conflicting", ex);

        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        problem.setTitle("Conflict");
        problem.setDetail("That change conflicts with data already stored");
        return problem;
    }
}
