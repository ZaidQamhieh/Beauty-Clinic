package com.example.backend.dtos;

import com.example.backend.entities.Patient;

import java.time.LocalDate;
import java.util.UUID;

// Demographics plus allergies. Admin, treating doctor, or the patient themselves.
public record PatientRecordResponse(
        UUID id,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        String phone,
        String email,
        String address,
        String languagePref,
        String allergies
) {
    public static PatientRecordResponse of(Patient patient) {
        return new PatientRecordResponse(
                patient.getId(),
                patient.getFirstName(),
                patient.getLastName(),
                patient.getDateOfBirth(),
                patient.getPhone(),
                patient.getEmail(),
                patient.getAddress(),
                patient.getLanguagePref(),
                patient.getAllergies()
        );
    }
}
