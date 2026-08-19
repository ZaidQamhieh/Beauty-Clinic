package com.example.backend.dtos;

import com.example.backend.entities.DoctorProfile.Specialization;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;

// The path identifies the account, so register and edit share one body.
public record DoctorProfileRequest(
        @Size(max = 20) List<Specialization> specializations,
        // Mirrors the column's CHECK, so a negative answers 400 rather than 409.
        @PositiveOrZero Integer yearsOfExperience
) {
}
