package com.example.backend.dtos;

import com.example.backend.entities.SessionRecord;
import com.example.backend.entities.SessionRecord.SkinReaction;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record SessionRecordResponse(
        UUID id,
        UUID sessionId,
        String authorName,
        String note,
        SkinReaction skinReaction,
        LocalDate followUpDate,
        UUID amendsId,
        Instant createdAt,
        List<UUID> prescribedProductIds
) {
    public static SessionRecordResponse of(SessionRecord record, List<UUID> prescribedProductIds) {
        return new SessionRecordResponse(
                record.getId(),
                record.getSession().getId(),
                record.getAuthor().getUser().fullName(),
                record.getNote(),
                record.getSkinReaction(),
                record.getFollowUpDate(),
                amendedIdOf(record),
                record.getCreatedAt(),
                prescribedProductIds
        );
    }

    // Null for an original note: only a correction amends anything.
    private static UUID amendedIdOf(SessionRecord record) {
        if (record.getAmends() == null) {
            return null;
        }
        return record.getAmends().getId();
    }
}
