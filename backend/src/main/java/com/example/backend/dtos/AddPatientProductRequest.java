package com.example.backend.dtos;

import com.example.backend.entities.PatientProduct.ProductSource;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;

import java.time.LocalDate;
import java.util.UUID;

public record AddPatientProductRequest(
        @NotNull UUID productId,
        @NotNull ProductSource source,
        // Discontinuing stamps today, so a future start would make the routine impossible to end.
        @PastOrPresent LocalDate startedOn
) {
}
