package com.example.backend.dtos;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;

public record ActivityLogResponse(
        String actorName,
        String patientName,
        String attemptedIdentifier,
        ActivityAction action,
        String entityType,
        Instant createdAt,
        JsonNode oldValues,
        JsonNode newValues
) {
    public static ActivityLogResponse from(ActivityLog log, String actorName, String patientName) {
        return new ActivityLogResponse(actorName, patientName, log.getAttemptedIdentifier(),
                log.getAction(), log.getEntityType(), log.getCreatedAt(),
                log.getOldValues(), log.getNewValues());
    }
}
