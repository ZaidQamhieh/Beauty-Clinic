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

    private static final LocalTime CLINIC_OPENS = LocalTime.of(7, 0);
    private static final LocalTime CLINIC_CLOSES = LocalTime.of(23, 59);

    // Nothing else checks this. An inverted window stores fine, then matches nothing.
    @AssertTrue(message = "endTime must be after startTime")
    private boolean isWindowOrdered() {
        return startTime == null || endTime == null || endTime.isAfter(startTime);
    }

    // The clinic's operating day: 7:00 AM through midnight.
    @AssertTrue(message = "startTime and endTime must fall within clinic hours (7:00 AM - 12:00 AM)")
    private boolean isWithinClinicHours() {
        return startTime == null || endTime == null
                || (!startTime.isBefore(CLINIC_OPENS) && !endTime.isAfter(CLINIC_CLOSES));
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

    // An override is a dated one-off; open-ended, one sick day hides the doctor for good.
    @AssertTrue(message = "effectiveTo is required for OVERRIDE")
    private boolean isOverrideBounded() {
        return kind != AvailabilityKind.OVERRIDE || effectiveTo != null;
    }
}
