package com.example.backend.exception;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

// Ranked ahead of the integrity handler, so an availability rejection reads as an
// availability rejection. The "code" property is what a client keys off; the plain
// overlap/cutoff rejections in DoctorAvailabilityService stay bare ResponseStatusExceptions
// and are unaffected by this handler.
@RestControllerAdvice
@Order(Ordered.LOWEST_PRECEDENCE - 20)
class AvailabilityExceptionHandler {

    @ExceptionHandler(AvailabilityShadowConfirmationRequiredException.class)
    ProblemDetail onShadowed(AvailabilityShadowConfirmationRequiredException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY);
        problem.setTitle("Confirmation required");
        problem.setDetail(ex.getMessage());
        problem.setProperty("code", "AVAILABILITY_SHADOWED");
        problem.setProperty("shadowedBy", ex.getShadowedBy());
        problem.setProperty("affectedDates", ex.getAffectedDates());
        return problem;
    }

    @ExceptionHandler(AvailabilityConflictException.class)
    ProblemDetail onConflict(AvailabilityConflictException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        problem.setTitle("Booked appointments would be affected");
        problem.setDetail(ex.getMessage());
        problem.setProperty("code", "AVAILABILITY_BOOKED_CONFLICT");
        problem.setProperty("conflicts", ex.getConflicts());
        return problem;
    }
}
