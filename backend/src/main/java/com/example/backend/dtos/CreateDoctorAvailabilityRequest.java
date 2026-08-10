package com.example.backend.dtos;

import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;

// RECURRING sets dayOfWeek; OVERRIDE sets a dated range and always wins.
public record CreateDoctorAvailabilityRequest(
        @NotNull AvailabilityKind kind,
        DayOfWeek dayOfWeek,
        @NotNull LocalTime startTime,
        @NotNull LocalTime endTime,
        boolean available,
        @NotNull LocalDate effectiveFrom,
        LocalDate effectiveTo
) {

    // Nothing else checks this. An inverted window stores fine, then matches nothing.
    @AssertTrue(message = "endTime must be after startTime")
    private boolean isWindowOrdered() {
        return startTime == null || endTime == null || endTime.isAfter(startTime);
    }

    // Mirrors doctor_availability_shape, so the caller gets a named error rather than a bare 409.
    @AssertTrue(message = "dayOfWeek is required for RECURRING and must be absent for OVERRIDE")
    private boolean isShapeValid() {
        if (kind == null) {
            return true;
        }
        if (kind == AvailabilityKind.RECURRING) {
            return dayOfWeek != null;
        }
        return dayOfWeek == null;
    }

    // Mirrors the effective_to CHECK: an inverted range is rejected here, not by the database.
    @AssertTrue(message = "effectiveTo must not be before effectiveFrom")
    private boolean isEffectiveRangeOrdered() {
        return effectiveFrom == null || effectiveTo == null || !effectiveTo.isBefore(effectiveFrom);
    }
}
