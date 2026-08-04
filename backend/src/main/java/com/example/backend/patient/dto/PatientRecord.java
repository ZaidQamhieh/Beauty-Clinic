package com.example.backend.patient.dto;

import com.example.backend.patient.Patient;

import java.time.LocalDate;
import java.util.UUID;

// Demographics plus allergies. Admin, treating doctor, or the patient themselves.
public record PatientRecord(
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
    public static PatientRecord of(Patient patient) {
        return new PatientRecord(
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
