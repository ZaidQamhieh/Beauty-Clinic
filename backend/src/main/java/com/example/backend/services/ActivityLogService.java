package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.repositories.ActivityLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import com.fasterxml.jackson.databind.JsonNode;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository activityLogs;

    @Transactional
    public void recordLogin(UUID userId) {
        recordUserEvent(userId, ActivityAction.LOGIN);
    }

    @Transactional
    public void recordLogout(UUID userId) {
        recordUserEvent(userId, ActivityAction.LOGOUT);
    }

    @Transactional
    public void recordRegistration(UUID userId) {
        recordUserEvent(userId, ActivityAction.ACCOUNT_REGISTERED);
    }

    // Must survive the rejected login transaction rolling back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailedLogin(String attemptedIdentifier) {
        activityLogs.save(
                ActivityLog.failedLogin(attemptedIdentifier)
        );
    }

    // Joins the caller's transaction: if the booking rolls back, so does the claim it happened.
    @Transactional
    public void recordAppointment(UUID actorId, UUID patientUserId, ActivityAction action, UUID appointmentId) {
        activityLogs.save(
                ActivityLog.onEntity(actorId, patientUserId, action, "appointment", appointmentId)
        );
    }

    @Transactional
    public void recordSession(UUID actorId, UUID patientUserId, ActivityAction action, UUID sessionId) {
        activityLogs.save(
                ActivityLog.onEntity(actorId, patientUserId, action, "appointment_session", sessionId)
        );
    }

    @Transactional
    public void recordClinicalProfileUpdate(
            UUID actorId, UUID patientUserId, JsonNode oldValues, JsonNode newValues
    ) {
        activityLogs.save(ActivityLog.clinicalProfileUpdated(actorId, patientUserId, oldValues, newValues));
    }

    // Joins the caller: REQUIRES_NEW cannot see the uncommitted user it references.
    @Transactional
    public void recordPermissionDenied(Optional<UUID> userId) {
        activityLogs.save(
                ActivityLog.permissionDenied(userId.orElse(null))
        );
    }

    @Transactional(readOnly = true)
    public Page<ActivityLog> search(ActivityAction action, Instant from, Instant to, String search, Pageable pageable) {
        String query = search == null || search.isBlank() ? null : search.trim();
        return activityLogs.search(action, from, to, query, pageable);
    }

    private void recordUserEvent(
            UUID userId,
            ActivityAction action
    ) {
        activityLogs.save(
                ActivityLog.forUser(userId, action)
        );
    }
}
