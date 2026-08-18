package com.example.backend.dtos;

import jakarta.validation.constraints.NotNull;

import java.util.Map;

public record PatientFormResponseDto(
        @NotNull Map<String, Object> answers
) {
}
