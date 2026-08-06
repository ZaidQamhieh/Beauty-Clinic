package com.example.backend.dtos;

import com.example.backend.entities.SessionRecord.SkinReaction;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record AmendSessionRecordRequest(
        String note,
        SkinReaction skinReaction,
        LocalDate followUpDate,
        List<UUID> prescribedProductIds
) {
}
