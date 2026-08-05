package com.example.backend.dtos;

import com.example.backend.entities.Patient;

import java.util.UUID;

public record PatientSummaryResponse(
        UUID id,
        String firstName,
        String lastName,
        String phone,
        String email
) {
    public static PatientSummaryResponse of(Patient patient) {
        return new PatientSummaryResponse(
                patient.getId(),
                patient.getFirstName(),
                patient.getLastName(),
                patient.getPhone(),
                patient.getEmail()
        );
    }
}
