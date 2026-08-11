package com.example.backend.dtos;

import com.example.backend.entities.SessionRecord.SkinReaction;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateSessionRecordRequest(
        @NotNull UUID sessionId,
        // The column is text; a note still has to fit in a person's reading.
        @Size(max = 4000) String note,
        SkinReaction skinReaction,
        LocalDate followUpDate,
        @Size(max = 20) List<UUID> prescribedProductIds
) {
}
