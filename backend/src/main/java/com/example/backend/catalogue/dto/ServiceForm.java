package com.example.backend.catalogue.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record ServiceForm(
        @NotBlank @Size(max = 150) String name,
        @Size(max = 150) String nameAr,
        @NotNull @Positive Integer durationMinutes,
        @NotNull @PositiveOrZero BigDecimal price
) {
}
