package com.example.backend.dtos;

import com.example.backend.entities.DoctorProfile.Specialization;
import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.security.Role;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Null;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.time.LocalDate;

public record UpdateOwnUserProfileRequest(
                @NotBlank @Size(max = 100) String firstName,
                @NotBlank @Size(max = 100) String lastName,
                @NotBlank @Size(max = 30) String phone,
                @Size(max = 2048) String imageUrl,
                @NotNull @Past(message = "Date of birth must be in the past") LocalDate dateOfBirth,
                @NotNull Gender gender,
                @Null(message = "Email cannot be changed here") String email,
                @Null(message = "Role cannot be changed here") Role role,
                @Size(max = 20) List<Specialization> specializations,
                @PositiveOrZero Integer yearsOfExperience) {
}
