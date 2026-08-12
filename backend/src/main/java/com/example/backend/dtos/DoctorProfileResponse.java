package com.example.backend.dtos;

import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.DoctorProfile.Specialization;

import java.util.List;

public record DoctorProfileResponse(
        List<Specialization> specializations,
        Integer yearsOfExperience
) {
    public static DoctorProfileResponse of(DoctorProfile profile) {
        return new DoctorProfileResponse(
                profile.getSpecializations(),
                profile.getYearsOfExperience()
        );
    }
}
