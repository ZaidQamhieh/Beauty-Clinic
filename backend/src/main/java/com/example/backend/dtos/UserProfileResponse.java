package com.example.backend.dtos;

import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.security.Role;

import java.time.LocalDate;
import java.util.UUID;

public record UserProfileResponse(
        UUID id,
        String firstName,
        String lastName,
        String email,
        String phone,
        LocalDate dateOfBirth,
        UserAccount.Gender gender,
        Role role,
        AccountStatus status,
        DoctorProfileResponse doctorProfile
) {
    public static UserProfileResponse of(UserAccount account, DoctorProfileResponse doctorProfile) {
        return new UserProfileResponse(
                account.getId(),
                account.getFirstName(),
                account.getLastName(),
                account.getEmail(),
                account.getPhone(),
                account.getDateOfBirth(),
                account.getGender(),
                account.getRole(),
                account.getStatus(),
                doctorProfile
        );
    }
}
