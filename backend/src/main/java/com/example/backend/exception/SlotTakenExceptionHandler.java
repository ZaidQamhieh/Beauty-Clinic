package com.example.backend.exception;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

// Ranked ahead of the integrity handler, so a lost slot reads as a lost slot.
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE - 20)
class SlotTakenExceptionHandler {

    @ExceptionHandler(SlotTakenException.class)
    ProblemDetail onSlotTaken(SlotTakenException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        problem.setTitle("That time has gone");
        problem.setDetail(ex.getMessage());
        return problem;
    }
}
