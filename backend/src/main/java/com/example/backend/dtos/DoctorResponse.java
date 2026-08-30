package com.example.backend.dtos;

import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.DoctorProfile.Specialization;

import java.util.List;
import java.util.UUID;

// Availability is its own table now, read at /api/doctors/{userId}/availability.
public record DoctorResponse(
        UUID userId,
        String fullName,
        List<Specialization> specializations,
        Integer yearsOfExperience,
        String imageUrl
) {
    public static DoctorResponse of(DoctorProfile doctor) {
        return new DoctorResponse(
                doctor.getUserId(),
                doctor.getUser().fullName(),
                doctor.getSpecializations(),
                doctor.getYearsOfExperience(),
                doctor.getUser().getImageUrl()
        );
    }
}
