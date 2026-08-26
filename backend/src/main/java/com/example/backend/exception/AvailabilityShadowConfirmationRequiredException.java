package com.example.backend.exception;

import com.example.backend.entities.DoctorAvailability.AvailabilityKind;

import java.time.LocalDate;
import java.util.List;

// Thrown instead of saving, when a new/edited availability row would have no
// effect on some of its dates because a higher-priority rule already covers them.
// Not a hard rejection: resubmitting with acknowledgeShadow=true skips this check.
public class AvailabilityShadowConfirmationRequiredException extends RuntimeException {

    // Null for the EXTRA_DAY case, where what's shadowing it is "the day's own
    // schedule" rather than one named higher-priority kind.
    private final AvailabilityKind shadowedBy;
    private final List<LocalDate> affectedDates;

    public AvailabilityShadowConfirmationRequiredException(
            String message, AvailabilityKind shadowedBy, List<LocalDate> affectedDates) {
        super(message);
        this.shadowedBy = shadowedBy;
        this.affectedDates = affectedDates;
    }

    public AvailabilityKind getShadowedBy() {
        return shadowedBy;
    }

    public List<LocalDate> getAffectedDates() {
        return affectedDates;
    }
}
