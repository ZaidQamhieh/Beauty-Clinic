package com.example.backend.dtos;

import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.security.Role;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record AccountResponse(
        UUID id,
        String email,
        String phone,
        String imageUrl,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        Gender gender,
        Role role,
        AccountStatus status,
        Instant createdAt,
        Instant updatedAt,
        DoctorProfileResponse doctorProfile
) {
    public static AccountResponse of(UserAccount account, DoctorProfileResponse doctorProfile) {
        return new AccountResponse(
                account.getId(),
                account.getEmail(),
                account.getPhone(),
                account.getImageUrl(),
                account.getFirstName(),
                account.getLastName(),
                account.getDateOfBirth(),
                account.getGender(),
                account.getRole(),
                account.getStatus(),
                account.getCreatedAt(),
                account.getUpdatedAt(),
                doctorProfile
        );
    }
}
