package com.example.backend.dtos;

import com.example.backend.security.Role;
import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.entities.UserAccount.AccountStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateAccountRequest(
                @NotBlank @Email @Size(max = 254) String email,
                @Size(min = 8, max = 72) String password,
                @Size(max = 30) String phone,
                @NotBlank @Size(max = 100) String firstName,
                @NotBlank @Size(max = 100) String lastName,
                LocalDate dateOfBirth,
                Gender gender,
                AccountStatus status,
                @NotNull Role role,
                @Valid DoctorProfileRequest doctorProfile) {
}
