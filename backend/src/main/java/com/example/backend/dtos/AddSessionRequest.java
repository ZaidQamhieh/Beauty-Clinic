package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

// A treatment in a visit. Category, price and length come from its tariff, not the caller.
public record AddSessionRequest(
        @NotNull UUID practitionerUserId,
        @NotNull TreatmentName treatmentName,
        // Not @FutureOrPresent: a slot that elapsed mid-booking is a lost slot, not bad input,
        // so AppointmentSessionService answers 409 for it.
        @NotNull Instant startTime
) {
}
