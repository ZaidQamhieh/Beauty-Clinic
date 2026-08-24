package com.example.backend.dtos;

import com.example.backend.entities.UserAccount.Gender;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

// Serves register and edit; edit ignores password.
public record PatientDetailsRequest(
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        @Past LocalDate dateOfBirth,
        @Size(max = 30) String phone,
        // 254 is the RFC email length limit.
        @NotBlank @Email @Size(max = 254) String email,
        Gender gender,
        // 72 is bcrypt's ceiling.
        @NotBlank @Size(min = 8, max = 72) String password,
        // Register requires it; edit must resend it.
        @Valid EditClinicalProfileRequest clinical
) {
}
