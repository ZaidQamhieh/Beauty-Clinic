package com.example.backend.entities;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "activity_log")
@Immutable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ActivityLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    // The table indexes activity by patient so a record's history is one query.
    @Column(name = "patient_user_id")
    private UUID patientUserId;

    @Column(name = "attempted_identifier", length = 255)
    private String attemptedIdentifier;

    // What was acted on. Both columns predate this and nothing wrote them, so no row was named.
    @Column(name = "entity_type", length = 60)
    private String entityType;

    @Column(name = "entity_id")
    private UUID entityId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "old_values", columnDefinition = "jsonb")
    private JsonNode oldValues;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "new_values", columnDefinition = "jsonb")
    private JsonNode newValues;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 60)
    private ActivityAction action;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    private ActivityLog(
            UUID userId,
            UUID patientUserId,
            String attemptedIdentifier,
            ActivityAction action,
            String entityType,
            UUID entityId
    ) {
        this.userId = userId;
        this.patientUserId = patientUserId;
        this.attemptedIdentifier = attemptedIdentifier;
        this.action = Objects.requireNonNull(action);
        this.entityType = entityType;
        this.entityId = entityId;
    }

    public static ActivityLog forUser(
            UUID userId,
            ActivityAction action
    ) {
        return new ActivityLog(
                Objects.requireNonNull(userId),
                null,
                null,
                action,
                null,
                null
        );
    }

    // Who did it, to whom, and to which row. userId is optional: some work has no human behind it.
    public static ActivityLog onEntity(
            UUID userId,
            UUID patientUserId,
            ActivityAction action,
            String entityType,
            UUID entityId
    ) {
        return new ActivityLog(
                userId,
                patientUserId,
                null,
                action,
                Objects.requireNonNull(entityType),
                Objects.requireNonNull(entityId)
        );
    }

    public static ActivityLog failedLogin(String identifier) {
        return new ActivityLog(
                null,
                null,
                Objects.requireNonNull(identifier),
                ActivityAction.LOGIN_FAILED,
                null,
                null
        );
    }

    public static ActivityLog permissionDenied(UUID userId) {
        return new ActivityLog(
                userId,
                null,
                null,
                ActivityAction.PERMISSION_DENIED,
                null,
                null
        );
    }

    public static ActivityLog clinicalProfileUpdated(
            UUID actorId, UUID patientUserId, JsonNode oldValues, JsonNode newValues
    ) {
        ActivityLog log = new ActivityLog(
                actorId, patientUserId, null, ActivityAction.CLINICAL_PROFILE_UPDATED,
                "patient_profile", patientUserId
        );
        log.oldValues = oldValues;
        log.newValues = newValues;
        return log;
    }
}