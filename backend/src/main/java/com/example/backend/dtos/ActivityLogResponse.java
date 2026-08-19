package com.example.backend.dtos;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;

import java.time.Instant;
import java.util.UUID;

public record ActivityLogResponse(
        UUID id,
        UUID userId,
        UUID patientUserId,
        String attemptedIdentifier,
        ActivityAction action,
        String entityType,
        UUID entityId,
        Instant createdAt
) {
    public static ActivityLogResponse from(ActivityLog log) {
        return new ActivityLogResponse(log.getId(), log.getUserId(), log.getPatientUserId(),
                log.getAttemptedIdentifier(), log.getAction(), log.getEntityType(),
                log.getEntityId(), log.getCreatedAt());
    }
}
