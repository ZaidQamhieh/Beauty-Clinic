package com.example.backend.dtos;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

// Reuses AddSessionRequest for the first treatment rather than repeating its fields.
public record BookAppointmentRequest(
        @NotNull UUID patientUserId,
        @NotNull @Valid AddSessionRequest session
) {
}
