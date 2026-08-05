package com.example.backend.dtos;

import com.example.backend.entities.Patient;

import java.time.LocalDate;
import java.util.UUID;

// Demographics only. Safe for reception - no clinical field exists to leak.
public record PatientDetailResponse(
        UUID id,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        String phone,
        String email,
        String address,
        String languagePref
) {
    public static PatientDetailResponse of(Patient patient) {
        return new PatientDetailResponse(
                patient.getId(),
                patient.getFirstName(),
                patient.getLastName(),
                patient.getDateOfBirth(),
                patient.getPhone(),
                patient.getEmail(),
                patient.getAddress(),
                patient.getLanguagePref()
        );
    }
}
