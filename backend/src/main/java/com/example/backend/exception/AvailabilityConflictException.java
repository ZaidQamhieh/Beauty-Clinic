package com.example.backend.exception;

import com.example.backend.entities.AppointmentSession.TreatmentName;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

// Thrown when a create/update/delete would leave an already-booked, non-cancelled
// session outside the newly-resolved open windows. Never skippable - unlike
// AvailabilityShadowConfirmationRequiredException, there is no acknowledging this.
public class AvailabilityConflictException extends RuntimeException {

    private final List<ConflictingSession> conflicts;

    public AvailabilityConflictException(String message, List<ConflictingSession> conflicts) {
        super(message);
        this.conflicts = conflicts;
    }

    public List<ConflictingSession> getConflicts() {
        return conflicts;
    }

    public record ConflictingSession(
            UUID sessionId,
            LocalDate date,
            LocalTime startTime,
            LocalTime endTime,
            TreatmentName treatmentName
    ) {
    }
}
