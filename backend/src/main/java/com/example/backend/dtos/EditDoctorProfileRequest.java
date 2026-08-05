package com.example.backend.dtos;

import jakarta.validation.constraints.Size;

public record EditDoctorProfileRequest(
        @Size(max = 120) String specialty,
        @Size(max = 60) String licenseNumber,
        String bio
) {
}
