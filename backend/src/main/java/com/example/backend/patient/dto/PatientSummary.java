package com.example.backend.patient.dto;

import com.example.backend.patient.Patient;

import java.util.UUID;

public record PatientSummary(
        UUID id,
        String firstName,
        String lastName,
        String phone,
        String email
) {
    public static PatientSummary of(Patient patient) {
        return new PatientSummary(
                patient.getId(),
                patient.getFirstName(),
                patient.getLastName(),
                patient.getPhone(),
                patient.getEmail()
        );
    }
}
