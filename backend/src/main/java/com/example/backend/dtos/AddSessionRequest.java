package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.Instant;
import java.util.UUID;

// A treatment within a visit. Category, price and duration come from it, not from the caller.
public record AddSessionRequest(
        @NotNull UUID practitionerUserId,
        @NotNull TreatmentName treatmentName,
        @NotNull @FutureOrPresent Instant startTime,
        // Null means the treatment's own duration; going past the standard maximum needs a doctor.
        @Positive Integer durationMinutes
) {
}
