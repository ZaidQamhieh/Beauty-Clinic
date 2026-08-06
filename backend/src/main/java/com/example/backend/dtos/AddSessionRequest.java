package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

// A later treatment in the same visit, possibly a different practitioner.
public record AddSessionRequest(
        @NotNull UUID practitionerUserId,
        @NotNull TreatmentCategory category,
        @NotNull TreatmentName treatmentName,
        @NotNull @DecimalMin(value = "0", inclusive = true) BigDecimal priceCharged,
        @NotNull @Positive Integer durationMinutes,
        @NotNull @FutureOrPresent Instant startTime
) {
}
