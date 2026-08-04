package com.example.backend.patient.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public final class PatientRequests {

    private PatientRequests() {
    }

    public record Register(
            @NotBlank @Size(max = 100) String firstName,
            @NotBlank @Size(max = 100) String lastName,
            @Past LocalDate dateOfBirth,
            @Size(max = 30) String phone,
            @Email @Size(max = 255) String email,
            String address,
            @Pattern(regexp = "en|ar") String languagePref
    ) {
    }

    public record Demographics(
            @NotBlank @Size(max = 100) String firstName,
            @NotBlank @Size(max = 100) String lastName,
            @Past LocalDate dateOfBirth,
            @Size(max = 30) String phone,
            @Email @Size(max = 255) String email,
            String address,
            @Pattern(regexp = "en|ar") String languagePref
    ) {
    }

    public record SelfUpdate(
            @Size(max = 30) String phone,
            String address,
            @Pattern(regexp = "en|ar") String languagePref
    ) {
    }

    public record Allergies(
            String allergies
    ) {
    }
}
