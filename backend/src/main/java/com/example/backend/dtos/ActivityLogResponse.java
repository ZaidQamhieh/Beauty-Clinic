package com.example.backend.dtos;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityCategory;
import com.example.backend.entities.ActivityLog;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;
import java.util.UUID;

public record ActivityLogResponse(
        String actorName,
        String patientName,
        String attemptedIdentifier,
        ActivityAction action,
        ActivityCategory category,
        String entityType,
        UUID correlationId,
        Instant createdAt,
        JsonNode oldValues,
        JsonNode newValues
) {
    public static ActivityLogResponse from(ActivityLog log, String actorName, String patientName) {
        return new ActivityLogResponse(actorName, patientName, log.getAttemptedIdentifier(),
                log.getAction(), log.getCategory(), log.getEntityType(), log.getCorrelationId(),
                log.getCreatedAt(), log.getOldValues(), log.getNewValues());
    }
}
