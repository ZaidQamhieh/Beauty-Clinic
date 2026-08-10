package com.example.backend.dtos;

import com.example.backend.entities.UserAccount.Gender;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

// Self-registration. There is deliberately no role field: the server always assigns PATIENT.
public record RegisterRequest(
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        // 254 is the RFC limit; 255 would register an unloggable address.
        @NotBlank @Email @Size(max = 254) String email,
        // 72 is bcrypt's ceiling; anything past it is silently ignored when hashing.
        @NotBlank @Size(min = 8, max = 72) String password,
        @Size(max = 30) String phone,
        @Past LocalDate dateOfBirth,
        Gender gender
) {
}
