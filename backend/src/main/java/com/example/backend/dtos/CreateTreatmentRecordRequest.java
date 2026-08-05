package com.example.backend.dtos;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record CreateTreatmentRecordRequest(
        @NotNull UUID appointmentId,
        String diagnosis,
        String treatment,
        String notes
) {
}
