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
}
