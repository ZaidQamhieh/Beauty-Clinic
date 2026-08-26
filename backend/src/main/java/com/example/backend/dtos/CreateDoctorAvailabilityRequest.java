package com.example.backend.dtos;

import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;

// REGULAR sets dayOfWeek + a window. VACATION is a bare dated range, no window at
// all. MODIFIED/EXTRA_DAY set a dated range and a window, no dayOfWeek.
// acknowledgeShadow re-submits a request the caller was already told is shadowed
// by a higher-priority rule for some of its dates, so the service can skip that
// check the second time.
public record CreateDoctorAvailabilityRequest(
        @NotNull AvailabilityKind kind,
        DayOfWeek dayOfWeek,
        LocalTime startTime,
        LocalTime endTime,
        @NotNull LocalDate effectiveFrom,
        LocalDate effectiveTo,
        boolean acknowledgeShadow
) {

    private static final LocalTime CLINIC_OPENS = LocalTime.of(7, 0);
    private static final LocalTime CLINIC_CLOSES = LocalTime.of(23, 59);
    private static final Duration MIN_DURATION = Duration.ofMinutes(30);

    // Nothing else checks this. An inverted window stores fine, then matches nothing.
    @AssertTrue(message = "endTime must be after startTime")
    private boolean isWindowOrdered() {
        return startTime == null || endTime == null || endTime.isAfter(startTime);
    }

    // A window under 30 minutes isn't a bookable slot for anything the clinic offers.
    @AssertTrue(message = "the window must be at least 30 minutes")
    private boolean isMinimumDuration() {
        return startTime == null || endTime == null
                || Duration.between(startTime, endTime).compareTo(MIN_DURATION) >= 0;
    }

    // The clinic's operating day: 7:00 AM through midnight.
    @AssertTrue(message = "startTime and endTime must fall within clinic hours (7:00 AM - 12:00 AM)")
    private boolean isWithinClinicHours() {
        return startTime == null || endTime == null
                || (!startTime.isBefore(CLINIC_OPENS) && !endTime.isAfter(CLINIC_CLOSES));
    }

    // Mirrors doctor_availability_shape: dayOfWeek and a window belong to different
    // kinds; VACATION carries neither window field.
    @AssertTrue(message = "dayOfWeek is required for REGULAR and must be absent otherwise")
    private boolean isShapeValid() {
        if (kind == null) {
            return true;
        }
        boolean dayOk = kind == AvailabilityKind.REGULAR ? dayOfWeek != null : dayOfWeek == null;
        boolean timeOk = kind == AvailabilityKind.VACATION
                ? startTime == null && endTime == null
                : startTime != null && endTime != null;
        return dayOk && timeOk;
    }

    // Mirrors the effective_to CHECK: an inverted range is rejected here, not by the database.
    @AssertTrue(message = "effectiveTo must not be before effectiveFrom")
    private boolean isEffectiveRangeOrdered() {
        return effectiveFrom == null || effectiveTo == null || !effectiveTo.isBefore(effectiveFrom);
    }

    // Every kind but REGULAR is a dated exception; open-ended, it would hide the
    // doctor (or add a shift) forever.
    @AssertTrue(message = "effectiveTo is required for every kind but REGULAR")
    private boolean isEffectiveToRequiredForExceptions() {
        return kind == AvailabilityKind.REGULAR || effectiveTo != null;
    }
}
