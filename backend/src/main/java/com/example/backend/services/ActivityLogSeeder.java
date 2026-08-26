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
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import static com.example.backend.entities.ActivityAction.*;

// Demo clinic history so the admin log is never empty: every filter option is
// guaranteed at least two rows on a fresh database, and a small sample is
// appended daily. Auth events are deliberately left out; login activity is
// recorded by the services themselves and hidden from the screen.
@Component
@RequiredArgsConstructor
class ActivityLogSeeder implements ApplicationRunner {

    // Actions the admin log hides, so seeding them is wasted rows.
    private static final List<ActivityAction> HIDDEN_EVENTS = List.of(
            LOGIN, LOGOUT, LOGIN_FAILED,
            CLINICAL_PROFILE_VIEWED, CLINICAL_HISTORY_VIEWED,
            CLINICAL_LIST_VIEWED, SESSION_RECORDS_VIEWED);

    // The entity each action touched, for the log's Entity column.
    private static final Map<ActivityAction, String> ENTITY_FOR = buildEntityMap();

    private final ActivityLogRepository activityLogs;
    private final UserAccountRepository users;

    @Value("${app.seed-activity-logs.enabled:true}")
    private boolean enabled;

    @Value("${app.seed-activity-logs.per-action:2}")
    private int perAction;

    @Value("${app.seed-activity-logs.daily:true}")
    private boolean daily;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            return;
        }

        var staff = staff();
        var patients = patients();
        if (staff.isEmpty() || patients.isEmpty()) {
            return;
        }

        // Guarantee data for every filter option that currently has none.
        var random = new Random(20260819L);
        for (ActivityAction action : ActivityAction.values()) {
            if (HIDDEN_EVENTS.contains(action)) {
                continue;
            }
            if (activityLogs.countByAction(action) == 0) {
                appendSamples(action, perAction, staff, patients,
                        Instant.now().minus(Duration.ofDays(7)), new Random(random.nextLong()));
            }
        }
    }

    // A little activity each morning so the log is never a stale snapshot.
    @Transactional
    @Scheduled(cron = "${app.seed-activity-logs.daily-cron:0 15 3 * * *}")
    public void writeDailySample() {
        if (!daily) {
            return;
        }
        appendRandom(5 + new Random().nextInt(8), Instant.now());
    }

    private void appendRandom(int count, Instant latest) {
        var staff = staff();
        var patients = patients();
        if (staff.isEmpty() || patients.isEmpty()) {
            return;
        }

        var random = new Random();
        var seed = new Random(random.nextLong());
        for (ActivityAction action : ActivityAction.values()) {
            if (!HIDDEN_EVENTS.contains(action)) {
                appendSamples(action, 1, staff, patients, latest, seed);
            }
        }
        appendSamples(BUSINESS_SAMPLE.get(random.nextInt(BUSINESS_SAMPLE.size())),
                count, staff, patients, latest, random);
    }

    private void appendSamples(
            ActivityAction action,
            int count,
            List<UserAccount> staff,
            List<UserAccount> patients,
            Instant latest,
            Random random
    ) {
        List<ActivityLog> rows = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            UserAccount actor = staff.get(random.nextInt(staff.size()));
            UserAccount patient = patients.get(random.nextInt(patients.size()));
            Instant at = latest
                    .minus(Duration.ofHours(random.nextInt(12)))
                    .minus(Duration.ofMinutes(random.nextInt(60)));

            if (action == PERMISSION_DENIED) {
                rows.add(ActivityLog.timed(actor.getId(), null, action, null, null, at));
                continue;
            }
            if (action == ACCOUNT_DELETED || action == DOCTOR_DELETED || action == PRODUCT_DELETED) {
                // The actor behind a deletion is the staff account removed.
                rows.add(ActivityLog.timed(
                        patient.getId(), null, action, ENTITY_FOR.get(action), UUID.randomUUID(), at));
                continue;
            }

            rows.add(ActivityLog.timed(
                    actor.getId(), patient.getId(), action, ENTITY_FOR.get(action), UUID.randomUUID(), at));
        }

        activityLogs.saveAll(rows);
    }

    private List<UserAccount> staff() {
        return users.findAllByRoleInOrderByLastNameAscFirstNameAsc(
                List.of(Role.ADMIN, Role.RECEPTIONIST, Role.DOCTOR));
    }

    private List<UserAccount> patients() {
        return users.findAllByRoleInOrderByLastNameAscFirstNameAsc(List.of(Role.PATIENT));
    }

    private static Map<ActivityAction, String> buildEntityMap() {
        Map<ActivityAction, String> map = new EnumMap<>(ActivityAction.class);

        for (ActivityAction action : List.of(
                APPOINTMENT_BOOKED, APPOINTMENT_RESCHEDULED, APPOINTMENT_CANCELLED)) {
            map.put(action, "appointment");
        }
        for (ActivityAction action : List.of(
                APPOINTMENT_SESSIONS_ADDED, SESSION_SCHEDULED, SESSION_STATUS_CHANGED,
                SESSION_CANCELLED, SESSION_COMPLETED, SESSION_NO_SHOW, SESSION_RECORDS_VIEWED)) {
            map.put(action, "appointment_session");
        }
        for (ActivityAction action : List.of(
                CLINICAL_PROFILE_VIEWED, CLINICAL_HISTORY_VIEWED, CLINICAL_LIST_VIEWED,
                CLINICAL_PROFILE_UPDATED, PROFILE_UPDATED)) {
            map.put(action, "patient_profile");
        }
        for (ActivityAction action : List.of(
                SESSION_RECORD_CREATED, SESSION_RECORD_AMENDED)) {
            map.put(action, "session_record");
        }
        for (ActivityAction action : List.of(
                ACCOUNT_REGISTERED, ACCOUNT_CREATED, ACCOUNT_UPDATED, ACCOUNT_DELETED,
                ACCOUNT_STATUS_CHANGED, PASSWORD_CHANGED, PASSWORD_RESET,
                PATIENT_REGISTERED_BY_STAFF, PATIENT_DEMOGRAPHICS_UPDATED,
                ACCOUNT_LOCKED, AUTH_RATE_LIMITED, STALE_SESSION_REJECTED,
                ROLE_CHANGE_REJECTED, DISABLED_ACCOUNT_REJECTED, REFRESH_TOKEN_REJECTED)) {
            map.put(action, "user_account");
        }
        for (ActivityAction action : List.of(
                DOCTOR_CREATED, DOCTOR_UPDATED, DOCTOR_DELETED)) {
            map.put(action, "doctor_profile");
        }
        for (ActivityAction action : List.of(AVAILABILITY_ADDED, AVAILABILITY_REMOVED)) {
            map.put(action, "doctor_availability");
        }
        for (ActivityAction action : List.of(
                PRODUCT_CREATED, PRODUCT_UPDATED, PRODUCT_DELETED)) {
            map.put(action, "product");
        }
        for (ActivityAction action : List.of(PATIENT_PRODUCT_ADDED, PATIENT_PRODUCT_DISCONTINUED)) {
            map.put(action, "patient_product");
        }
        for (ActivityAction action : List.of(
                FORM_QUESTION_CREATED, FORM_QUESTION_UPDATED,
                FORM_QUESTION_ACTIVATED, FORM_QUESTION_DEACTIVATED)) {
            map.put(action, "form_question");
        }

        return map;
    }

    private static final List<ActivityAction> BUSINESS_SAMPLE = List.of(
            APPOINTMENT_BOOKED, SESSION_SCHEDULED,
            SESSION_COMPLETED, CLINICAL_PROFILE_UPDATED, PRODUCT_CREATED
    );
}