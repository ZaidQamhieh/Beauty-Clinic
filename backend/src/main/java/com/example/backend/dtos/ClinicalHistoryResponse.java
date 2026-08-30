package com.example.backend.dtos;

import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.PatientProduct;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/** An immutable record of a saved clinical-intake revision. */
public record ClinicalHistoryResponse(
        UUID id,
    String action,
        UUID actorId,
        String actorName,
        Instant changedAt,
    String productName,
    String productBrand,
    String productType,
    String source,
    String startedOn,
    String stoppedOn,
        Map<String, Object> previousValues,
        Map<String, Object> newValues
) {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static ClinicalHistoryResponse of(ActivityLog log, String actorName) {
        return of(log, actorName, null);
        }

        public static ClinicalHistoryResponse of(
            ActivityLog log, String actorName, PatientProduct patientProduct) {
        var product = patientProduct == null ? null : patientProduct.getProduct();
        return new ClinicalHistoryResponse(
                log.getId(),
            log.getAction().name(),
                log.getUserId(),
                actorName,
                log.getCreatedAt(),
            product == null ? null : product.getName(),
            product == null || product.getBrand() == null ? null : product.getBrand().name(),
            product == null || product.getProductType() == null ? null : product.getProductType().name(),
            patientProduct == null || patientProduct.getSource() == null ? null : patientProduct.getSource().name(),
            patientProduct == null || patientProduct.getStartedOn() == null ? null : patientProduct.getStartedOn().toString(),
            patientProduct == null || patientProduct.getDiscontinuedOn() == null ? null : patientProduct.getDiscontinuedOn().toString(),
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
