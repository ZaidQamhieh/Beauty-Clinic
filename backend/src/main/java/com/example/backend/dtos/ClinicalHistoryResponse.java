package com.example.backend.dtos;

import com.example.backend.entities.ActivityLog;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/** An immutable record of a saved clinical-intake revision. */
public record ClinicalHistoryResponse(
        UUID id,
        UUID actorId,
        String actorName,
        Instant changedAt,
        Map<String, Object> previousValues,
        Map<String, Object> newValues
) {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static ClinicalHistoryResponse of(ActivityLog log, String actorName) {
        return new ClinicalHistoryResponse(
                log.getId(),
                log.getUserId(),
                actorName,
                log.getCreatedAt(),
                toMap(log.getOldValues()),
                toMap(log.getNewValues())
        );
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> toMap(JsonNode node) {
        if (node == null || node.isNull() || node.isMissingNode()) {
            return Map.of();
        }
        try {
            return MAPPER.convertValue(node, Map.class);
        } catch (Exception e) {
            return Map.of();
        }
    }
}
