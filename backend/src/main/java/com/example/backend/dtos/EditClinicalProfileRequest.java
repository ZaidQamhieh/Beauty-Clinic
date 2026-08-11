package com.example.backend.dtos;

import com.example.backend.entities.PatientProfile.Allergy;
import com.example.backend.entities.PatientProfile.ChronicCondition;
import com.example.backend.entities.PatientProfile.Medication;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.PatientProfile.SmokingStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

// A PUT states every clinical fact; send [] to clear a list.
public record EditClinicalProfileRequest(
        @NotNull Boolean pregnantBreastfeeding,
        // Required: the one answer that marks the form filled, since the rest may be empty.
        @NotNull SkinType skinType,
        // Nullable column, so an absent value legitimately means unknown.
        SmokingStatus smokingStatus,
        // Capped above the enum's size: deduped later, but deserialized in full first.
        @NotNull @Size(max = 20) List<Allergy> allergies,
        @NotNull @Size(max = 20) List<Medication> medications,
        @NotNull @Size(max = 20) List<ChronicCondition> chronicConditions
) {
}
