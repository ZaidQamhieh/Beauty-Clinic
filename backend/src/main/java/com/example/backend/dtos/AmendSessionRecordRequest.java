package com.example.backend.dtos;

import com.example.backend.entities.SessionRecord.SkinReaction;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record AmendSessionRecordRequest(
        // Bounded like the record it corrects, so an amendment cannot outgrow the original.
        @Size(max = 4000) String note,
        SkinReaction skinReaction,
        LocalDate followUpDate,
        @Size(max = 20) List<UUID> prescribedProductIds
) {
}
