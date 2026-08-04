package com.example.backend.patient.dto;

import com.example.backend.patient.Patient;

import java.time.LocalDate;
import java.util.UUID;

public final class PatientViews {

    private PatientViews() {
    }

    public record Summary(
            UUID id,
            String firstName,
            String lastName,
            String phone,
            String email
    ) {
        public static Summary of(Patient patient) {
            return new Summary(
                    patient.getId(),
                    patient.getFirstName(),
                    patient.getLastName(),
                    patient.getPhone(),
                    patient.getEmail()
            );
        }
    }

    public record Detail(
            UUID id,
            String firstName,
            String lastName,
            LocalDate dateOfBirth,
            String phone,
            String email,
            String address,
            String languagePref
    ) {
        public static Detail of(Patient patient) {
            return new Detail(
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

    public record Clinical(
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
        public static Clinical of(Patient patient) {
            return new Clinical(
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
}
