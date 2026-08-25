package com.example.backend.services;

import com.example.backend.dtos.ActivityLogResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.UserAccount;
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

import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

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
    public Page<ActivityLogResponse> search(ActivityAction action, Instant from, Instant to, String search, Pageable pageable) {
        String term = search == null || search.isBlank() ? null : search.trim();

        List<UUID> accountIds = accountIdsFor(term);

        Page<ActivityLog> page = activityLogs.findAll((root, query, cb) -> {
            var predicates = new ArrayList<Predicate>();

            if (action != null) {
                predicates.add(cb.equal(root.get("action"), action));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThan(root.get("createdAt"), to));
            }
            if (term != null) {
                predicates.add(matching(root, cb, term, accountIds));
            }

            // Auth events clutter the admin log.
            predicates.add(cb.not(
                    root.get("action").in(ActivityAction.LOGIN, ActivityAction.LOGOUT, ActivityAction.LOGIN_FAILED)
            ));

            return cb.and(predicates.toArray(new Predicate[0]));
        }, stable(pageable));

        List<UUID> ids = page.stream()
                .flatMap(log -> Stream.of(log.getUserId(), log.getPatientUserId()))
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, String> names = users.findAllById(ids).stream()
                .collect(Collectors.toMap(UserAccount::getId, UserAccount::fullName));

        return page.map(log -> ActivityLogResponse.from(
                log, names.get(log.getUserId()), names.get(log.getPatientUserId())));
    }

    private Predicate matching(
            Root<ActivityLog> root, CriteriaBuilder cb, String term, List<UUID> accountIds
    ) {

        String pattern = pattern(term);
        var predicates = new ArrayList<Predicate>();

        predicates.add(cb.like(cb.lower(cb.coalesce(root.get("attemptedIdentifier"), "")), pattern));
        predicates.add(cb.like(cb.lower(cb.coalesce(root.get("entityType"), "")), pattern));

        if (!accountIds.isEmpty()) {
            predicates.add(root.get("userId").in(accountIds));
            predicates.add(root.get("patientUserId").in(accountIds));
        }

        return cb.or(predicates.toArray(new Predicate[0]));
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
    private List<UUID> accountIdsFor(String term) {
        if (term == null) {
            return List.of();
        }

        return users.findIdsMatching(pattern(term));
    }

    private String pattern(String term) {
        return "%" + term.toLowerCase(Locale.ROOT) + "%";
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
