package com.example.backend.dtos;

import com.example.backend.entities.SessionRecord.SkinReaction;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateSessionRecordRequest(
        @NotNull UUID sessionId,
        String note,
        SkinReaction skinReaction,
        LocalDate followUpDate,
        List<UUID> prescribedProductIds
) {
}
