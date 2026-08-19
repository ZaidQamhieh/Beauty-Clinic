package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    // Matches nothing, keeping every parameter bound.
    private static final UUID NO_MATCH = new UUID(0L, 0L);
    private static final String NO_TEXT = "-";
    private static final Instant SINCE_ALWAYS = Instant.EPOCH.minusSeconds(62_167_219_200L);
    private static final Instant UNTIL_FOREVER = Instant.EPOCH.plusSeconds(253_402_300_799L);

    private final ActivityLogRepository activityLogs;
    private final UserAccountRepository users;
    private final ActivityCorrelation correlation;
    // Jackson 2 kept for Hibernate JsonNode.
    private final ObjectMapper objectMapper = new ObjectMapper();

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

    // Survives the rejected login rolling back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailedLogin(String attemptedIdentifier) {
        activityLogs.save(
                ActivityLog.failedLogin(attemptedIdentifier)
        );
    }

    // Joins the caller: rolled-back bookings claim nothing.
    @Transactional
    public void recordAppointment(UUID actorId, UUID patientUserId, ActivityAction action, UUID appointmentId) {
        activityLogs.save(ActivityLog.of(
                actorId, patientUserId, action, "appointment", appointmentId, null, correlationNode()));
    }

    @Transactional
    public void recordSession(UUID actorId, UUID patientUserId, ActivityAction action, UUID sessionId) {
        activityLogs.save(ActivityLog.of(
                actorId, patientUserId, action, "appointment_session", sessionId, null, correlationNode()));
    }

    @Transactional
    public void recordClinicalProfileUpdate(
            UUID actorId, UUID patientUserId, JsonNode oldValues, JsonNode newValues
    ) {
        activityLogs.save(ActivityLog.clinicalProfileUpdated(actorId, patientUserId, oldValues, newValues));
    }

    // A denial outlives the work it refused.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordPermissionDenied(Optional<UUID> userId) {
        // Only a committed actor is visible here.
        activityLogs.save(
                ActivityLog.permissionDenied(userId.filter(users::existsById).orElse(null))
        );
    }

    // Ordinary state change, tied to its caller.
    @Transactional
    public void record(UUID actorId, UUID patientUserId, ActivityAction action, String entityType, UUID entityId) {
        record(actorId, patientUserId, action, entityType, entityId, null, null);
    }

    @Transactional
    public void record(
            UUID actorId,
            UUID patientUserId,
            ActivityAction action,
            String entityType,
            UUID entityId,
            JsonNode oldValues,
            JsonNode newValues
    ) {
        activityLogs.save(ActivityLog.of(
                actorId, patientUserId, action, entityType, entityId, oldValues, newValues));
    }

    // Reads and security events never roll back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordIndependently(
            UUID actorId, UUID patientUserId, ActivityAction action, String entityType, UUID entityId
    ) {
        activityLogs.save(ActivityLog.of(
                actorId, patientUserId, action, entityType, entityId, null, null));
    }

    @Transactional(readOnly = true)
    public Page<ActivityLog> clinicalHistory(UUID patientUserId, Pageable pageable) {
        return activityLogs.findByPatientUserIdAndActionOrderByCreatedAtDescIdDesc(
                patientUserId, ActivityAction.CLINICAL_PROFILE_UPDATED, pageable);
    }

    @Transactional(readOnly = true)
    public Page<ActivityLog> search(ActivityAction action, Instant from, Instant to, String search, Pageable pageable) {
        String query = search == null || search.isBlank() ? null : search.trim();

        UUID id = asUuid(query);
        String text = id == null && query != null ? "%" + escaped(query) + "%" : null;

        return activityLogs.search(
                action,
                from == null ? SINCE_ALWAYS : from,
                to == null ? UNTIL_FOREVER : to,
                query != null,
                text == null ? NO_TEXT : text,
                id == null ? NO_MATCH : id,
                actorIdsFor(text),
                stable(pageable));
    }

    // Ties the rows one operation writes together.
    private JsonNode correlationNode() {
        Optional<UUID> id = correlation.current();

        if (id.isEmpty()) {
            return null;
        }

        ObjectNode node = objectMapper.createObjectNode();
        node.put("correlationId", id.get().toString());
        return node;
    }

    // The screen promises names, so resolve them.
    private List<UUID> actorIdsFor(String text) {
        if (text == null) {
            return List.of(NO_MATCH);
        }

        List<UUID> matches = users.findIdsMatching(text);
        return matches.isEmpty() ? List.of(NO_MATCH) : matches;
    }

    // Wildcards typed by a user stay literal.
    private String escaped(String query) {
        return query.toLowerCase()
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }

    private UUID asUuid(String query) {
        if (query == null) {
            return null;
        }

        try {
            return UUID.fromString(query);
        } catch (IllegalArgumentException notAnId) {
            return null;
        }
    }

    // Timestamps tie, so page edges need settling.
    private Pageable stable(Pageable pageable) {
        if (pageable.isUnpaged() || pageable.getSort().getOrderFor("id") != null) {
            return pageable;
        }

        return PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                pageable.getSort().and(Sort.by(Sort.Direction.DESC, "id")));
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
