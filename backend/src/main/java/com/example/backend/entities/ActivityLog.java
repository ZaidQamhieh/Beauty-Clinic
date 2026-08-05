package com.example.backend.entities;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;

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

    @Column(name = "attempted_identifier", length = 255)
    private String attemptedIdentifier;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 60)
    private ActivityAction action;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    private ActivityLog(
            UUID userId,
            String attemptedIdentifier,
            ActivityAction action
    ) {
        this.userId = userId;
        this.attemptedIdentifier = attemptedIdentifier;
        this.action = Objects.requireNonNull(action);
    }

    public static ActivityLog forUser(
            UUID userId,
            ActivityAction action
    ) {
        return new ActivityLog(
                Objects.requireNonNull(userId),
                null,
                action
        );
    }

    public static ActivityLog failedLogin(String identifier) {
        return new ActivityLog(
                null,
                Objects.requireNonNull(identifier),
                ActivityAction.LOGIN_FAILED
        );
    }

    public static ActivityLog permissionDenied(UUID userId) {
        return new ActivityLog(
                userId,
                null,
                ActivityAction.PERMISSION_DENIED
        );
    }
}