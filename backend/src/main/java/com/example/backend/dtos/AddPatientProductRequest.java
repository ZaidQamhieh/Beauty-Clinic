package com.example.backend.dtos;

import com.example.backend.entities.PatientProduct.ProductSource;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.UUID;

public record AddPatientProductRequest(
        @NotNull UUID productId,
        @NotNull ProductSource source,
        LocalDate startedOn
) {
}
