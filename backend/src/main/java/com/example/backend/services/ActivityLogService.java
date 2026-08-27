package com.example.backend.services;

import com.example.backend.dtos.ActivityLogResponse;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityCategory;
import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
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
import java.time.Duration;
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

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository activityLogs;
    private final UserAccountRepository users;
    private final ActivityCorrelation correlation;

    // One row per patient per window.
    @Value("${app.activity-log.view-window-minutes:15}")
    private long viewWindowMinutes;

    @Transactional
    public void recordRegistration(UUID userId) {
        activityLogs.save(stamp(ActivityLog.forUser(userId, ActivityAction.ACCOUNT_REGISTERED)));
    }

    // Survives the rejected login rolling back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailedLogin(String attemptedIdentifier) {
        activityLogs.save(stamp(ActivityLog.failedLogin(attemptedIdentifier)));
    }

    // Joins the caller: rolled-back bookings claim nothing.
    @Transactional
    public void recordAppointment(UUID actorId, UUID patientUserId, ActivityAction action, UUID appointmentId) {
        record(actorId, patientUserId, action, "appointment", appointmentId);
    }

    @Transactional
    public void recordSession(UUID actorId, UUID patientUserId, ActivityAction action, UUID sessionId) {
        record(actorId, patientUserId, action, "appointment_session", sessionId);
    }

    @Transactional
    public void recordClinicalProfileUpdate(
            UUID actorId, UUID patientUserId, JsonNode oldValues, JsonNode newValues
    ) {
        record(actorId, patientUserId, ActivityAction.CLINICAL_PROFILE_UPDATED,
                "patient_profile", patientUserId, oldValues, newValues);
    }

    // A denial outlives the work it refused.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordPermissionDenied(Optional<UUID> userId) {
        // Only a committed actor is visible here.
        activityLogs.save(
                stamp(ActivityLog.permissionDenied(userId.filter(users::existsById).orElse(null)))
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
        activityLogs.save(stamp(ActivityLog.of(
                actorId, patientUserId, action, entityType, entityId, oldValues, newValues)));
    }

    // Nothing changed, so nothing happened.
    @Transactional
    public void recordChange(
            UUID actorId,
            UUID patientUserId,
            ActivityAction action,
            String entityType,
            UUID entityId,
            ActivityDiff.Change change
    ) {
        if (change.isEmpty()) {
            return;
        }

        record(actorId, patientUserId, action, entityType, entityId, change.before(), change.after());
    }

    // Security events never roll back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordIndependently(
            UUID actorId, UUID patientUserId, ActivityAction action, String entityType, UUID entityId
    ) {
        activityLogs.save(stamp(ActivityLog.of(actorId, patientUserId, action, entityType, entityId, null, null)));
    }

    // Reads outlive the query that triggered them.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordView(
            UUID actorId, UUID patientUserId, ActivityAction action, String entityType, UUID entityId
    ) {
        if (actorId == null || patientUserId == null) {
            return;
        }

        Instant since = Instant.now().minus(Duration.ofMinutes(viewWindowMinutes));

        if (activityLogs.existsByUserIdAndPatientUserIdAndActionAndCreatedAtAfter(
                actorId, patientUserId, action, since)) {
            return;
        }

        activityLogs.save(stamp(ActivityLog.of(actorId, patientUserId, action, entityType, entityId, null, null)));
    }

    @Transactional(readOnly = true)
    public Page<ActivityLog> clinicalHistory(UUID patientUserId, Pageable pageable) {
        return activityLogs.findByPatientUserIdAndActionOrderByCreatedAtDescIdDesc(
                patientUserId, ActivityAction.CLINICAL_PROFILE_UPDATED, pageable);
    }

    // Page doesn't round-trip through the Redis ObjectMapper.
    @Transactional(readOnly = true)
    public Page<ActivityLogResponse> search(
            ActivityAction action,
            ActivityCategory category,
            Instant from,
            Instant to,
            String search,
            Pageable pageable
    ) {
        String term = search == null || search.isBlank() ? null : search.trim();

        List<UUID> accountIds = accountIdsFor(term);

        Page<ActivityLog> page = activityLogs.findAll((root, query, cb) -> {
            var predicates = new ArrayList<Predicate>();

            if (action != null) {
                predicates.add(cb.equal(root.get("action"), action));
            }
            if (category != null) {
                predicates.add(cb.equal(root.get("category"), category));
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

            // Retired actions are history, not current activity.
            predicates.add(cb.notEqual(root.get("category"), ActivityCategory.LEGACY));

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
    private ActivityLog stamp(ActivityLog log) {
        return log.correlatedWith(correlation.current().orElse(null));
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
}
