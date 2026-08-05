package com.example.backend.dtos;

import com.example.backend.entities.WorkingHours;
import com.example.backend.entities.Doctor;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

public record DoctorResponse(
        UUID userId,
        String fullName,
        String specialty,
        String licenseNumber,
        String bio,
        List<WorkingHours> availability,
        List<ClinicServiceResponse> services
) {
    public static DoctorResponse of(Doctor doctor) {
        return new DoctorResponse(
                doctor.getUserId(),
                doctor.getUser().getFullName(),
                doctor.getSpecialty(),
                doctor.getLicenseNumber(),
                doctor.getBio(),
                doctor.getAvailability(),
                doctor.getServices().stream()
                        .map(ClinicServiceResponse::of)
                        .sorted(Comparator.comparing(ClinicServiceResponse::name))
                        .toList()
        );
    }
}
