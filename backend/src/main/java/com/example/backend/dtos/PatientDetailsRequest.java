package com.example.backend.dtos;

import com.example.backend.entities.UserAccount.Gender;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

// Serves register and edit. Registration also creates the account, INVITED and
// passwordless.
public record PatientDetailsRequest(
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        @Past LocalDate dateOfBirth,
        @Size(max = 30) String phone,
        // 254 is the RFC limit; 255 would register an unloggable address.
        @NotBlank @Email @Size(max = 254) String email,
        Gender gender
) {
}
