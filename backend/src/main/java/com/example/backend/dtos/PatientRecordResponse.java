package com.example.backend.dtos;

import com.example.backend.entities.PatientProfile.Allergy;
import com.example.backend.entities.PatientProfile.ChronicCondition;
import com.example.backend.entities.UserAccount.Gender;
import com.example.backend.entities.PatientProfile.Medication;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.PatientProfile.SmokingStatus;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

// Demographics plus clinical intake: admin, treating doctor, or the patient themselves.
public record PatientRecordResponse(
        UUID id,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        String phone,
        String imageUrl,
        String email,
        Gender gender,
        boolean pregnantBreastfeeding,
        SkinType skinType,
        SmokingStatus smokingStatus,
        List<Allergy> allergies,
        List<Medication> medications,
        List<ChronicCondition> chronicConditions
) {
    public static PatientRecordResponse of(PatientProfile profile) {
        var user = profile.getUser();
        return new PatientRecordResponse(
                profile.getUserId(),
                user.getFirstName(),
                user.getLastName(),
                user.getDateOfBirth(),
                user.getPhone(),
                user.getImageUrl(),
                user.getEmail(),
                user.getGender(),
                profile.isPregnantBreastfeeding(),
                profile.getSkinType(),
                profile.getSmokingStatus(),
                profile.getAllergies(),
                profile.getMedications(),
                profile.getChronicConditions()
        );
    }
}
