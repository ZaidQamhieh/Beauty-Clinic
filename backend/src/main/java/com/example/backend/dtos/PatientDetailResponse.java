package com.example.backend.dtos;

import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.entities.PatientProfile;

import java.time.LocalDate;
import java.util.UUID;

// Demographics only, so reception gets a shape with no clinical field to leak.
public record PatientDetailResponse(
        UUID id,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        String phone,
        String email,
        Gender gender
) {
    public static PatientDetailResponse of(PatientProfile profile) {
        var user = profile.getUser();
        return new PatientDetailResponse(
                profile.getUserId(),
                user.getFirstName(),
                user.getLastName(),
                user.getDateOfBirth(),
                user.getPhone(),
                user.getEmail(),
                user.getGender()
        );
    }
}
