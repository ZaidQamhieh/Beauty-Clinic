package com.example.backend.dtos;

import com.example.backend.entities.PatientProfile.Allergy;
import com.example.backend.entities.PatientProfile.ChronicCondition;
import com.example.backend.entities.PatientProfile.Medication;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.PatientProfile.SmokingStatus;
import jakarta.validation.constraints.NotNull;

import java.util.List;

// A PUT states every clinical fact; send [] to clear a list.
public record EditClinicalProfileRequest(
        @NotNull Boolean pregnantBreastfeeding,
        // Nullable columns, so an absent value legitimately means unknown.
        SkinType skinType,
        SmokingStatus smokingStatus,
        @NotNull List<Allergy> allergies,
        @NotNull List<Medication> medications,
        @NotNull List<ChronicCondition> chronicConditions
) {
}
