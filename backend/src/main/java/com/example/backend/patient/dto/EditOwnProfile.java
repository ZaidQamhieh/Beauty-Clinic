package com.example.backend.patient.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EditOwnProfile(
        @Size(max = 30) String phone,
        String address,
        @Pattern(regexp = "en|ar") String languagePref
) {
}
