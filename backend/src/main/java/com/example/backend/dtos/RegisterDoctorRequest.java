package com.example.backend.dtos;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

// Links an existing DOCTOR-role account to a practising profile.
public record RegisterDoctorRequest(
        @NotNull UUID userId,
        @Size(max = 120) String specialty,
        @Size(max = 60) String licenseNumber,
        String bio
) {
}
