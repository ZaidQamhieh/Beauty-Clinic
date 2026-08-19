package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;

// Demo clinic history so the admin log is not empty on a fresh database.
// Only auth events are deliberately left out; login activity is recorded
// by the services themselves and hidden from the screen.
@Component
@RequiredArgsConstructor
class ActivityLogSeeder implements ApplicationRunner {

    private static final List<ActivityAction> BUSINESS_ACTIONS = List.of(
            ActivityAction.ACCOUNT_REGISTERED,
            ActivityAction.PATIENT_REGISTERED_BY_STAFF,
            ActivityAction.PATIENT_DEMOGRAPHICS_UPDATED,
            ActivityAction.PROFILE_UPDATED,
            ActivityAction.PERMISSION_DENIED,
            ActivityAction.APPOINTMENT_BOOKED,
            ActivityAction.APPOINTMENT_RESCHEDULED,
            ActivityAction.APPOINTMENT_CANCELLED,
            ActivityAction.APPOINTMENT_SESSIONS_ADDED,
            ActivityAction.SESSION_SCHEDULED,
            ActivityAction.SESSION_STATUS_CHANGED,
            ActivityAction.SESSION_CANCELLED,
            ActivityAction.SESSION_COMPLETED,
            ActivityAction.SESSION_NO_SHOW,
            ActivityAction.CLINICAL_PROFILE_VIEWED,
            ActivityAction.CLINICAL_HISTORY_VIEWED,
            ActivityAction.CLINICAL_LIST_VIEWED,
            ActivityAction.SESSION_RECORDS_VIEWED,
            ActivityAction.CLINICAL_PROFILE_UPDATED,
            ActivityAction.SESSION_RECORD_CREATED,
            ActivityAction.SESSION_RECORD_AMENDED,
            ActivityAction.DOCTOR_UPDATED,
            ActivityAction.AVAILABILITY_ADDED,
            ActivityAction.PRODUCT_CREATED,
            ActivityAction.PRODUCT_UPDATED,
            ActivityAction.FORM_QUESTION_CREATED,
            ActivityAction.FORM_QUESTION_ACTIVATED
    );

    private static final List<String> ENTITIES = List.of(
            "appointment", "appointment_session", "patient_profile",
            "product", "doctor_availability", "form_question"
    );

    private final ActivityLogRepository activityLogs;
    private final UserAccountRepository users;

    @Value("${app.seed-activity-logs.enabled:true}")
    private boolean enabled;

    @Value("${app.seed-activity-logs.min-rows:30}")
    private long minRows;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            return;
        }
        if (activityLogs.count() >= minRows) {
            return;
        }

        List<UserAccount> staff = users.findAllByRoleInOrderByLastNameAscFirstNameAsc(
                List.of(Role.ADMIN, Role.RECEPTIONIST, Role.DOCTOR));
        List<UserAccount> patients = users.findAllByRoleInOrderByLastNameAscFirstNameAsc(List.of(Role.PATIENT));

        if (staff.isEmpty() || patients.isEmpty()) {
            return;
        }

        var random = new Random(20260819L);
        List<ActivityLog> rows = new ArrayList<>();

        for (int i = 0; i < 70; i++) {
            UserAccount actor = staff.get(random.nextInt(staff.size()));
            UserAccount patient = patients.get(random.nextInt(patients.size()));
            ActivityAction action = BUSINESS_ACTIONS.get(random.nextInt(BUSINESS_ACTIONS.size()));
            Instant at = Instant.now()
                    .minus(Duration.ofDays(random.nextInt(14)))
                    .minus(Duration.ofHours(random.nextInt(10)))
                    .minus(Duration.ofMinutes(random.nextInt(60)));

            if (action == ActivityAction.PERMISSION_DENIED) {
                rows.add(ActivityLog.timed(actor.getId(), null, action, null, null, at));
                continue;
            }

            String entityType = ENTITIES.get(random.nextInt(ENTITIES.size()));
            rows.add(ActivityLog.timed(
                    actor.getId(), patient.getId(), action, entityType, UUID.randomUUID(), at));
        }

        activityLogs.saveAll(rows);
    }
}