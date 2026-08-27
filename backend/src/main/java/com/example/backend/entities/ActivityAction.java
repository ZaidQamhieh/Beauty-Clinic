package com.example.backend.entities;

import static com.example.backend.entities.ActivityCategory.ADMIN;
import static com.example.backend.entities.ActivityCategory.CLINICAL;
import static com.example.backend.entities.ActivityCategory.LEGACY;
import static com.example.backend.entities.ActivityCategory.SECURITY;

// Plain varchar column; list grows freely.
public enum ActivityAction {

    // Clinical record authorship and edits.
    CLINICAL_PROFILE_UPDATED(CLINICAL),
    PATIENT_DEMOGRAPHICS_UPDATED(CLINICAL),
    SESSION_RECORD_CREATED(CLINICAL),
    SESSION_RECORD_AMENDED(CLINICAL),

    // Reads of clinical information.
    CLINICAL_PROFILE_VIEWED(CLINICAL),
    CLINICAL_HISTORY_VIEWED(CLINICAL),
    SESSION_RECORDS_VIEWED(CLINICAL),

    // Scheduling.
    APPOINTMENT_BOOKED(CLINICAL),
    APPOINTMENT_RESCHEDULED(CLINICAL),
    APPOINTMENT_CANCELLED(CLINICAL),
    APPOINTMENT_SESSIONS_ADDED(CLINICAL),
    SESSION_SCHEDULED(CLINICAL),
    SESSION_CANCELLED(CLINICAL),
    SESSION_COMPLETED(CLINICAL),
    SESSION_NO_SHOW(CLINICAL),
    PATIENT_PRODUCT_ADDED(CLINICAL),
    PATIENT_PRODUCT_DISCONTINUED(CLINICAL),

    // Account administration.
    ACCOUNT_REGISTERED(ADMIN),
    ACCOUNT_CREATED(ADMIN),
    ACCOUNT_UPDATED(ADMIN),
    ACCOUNT_DELETED(ADMIN),
    PASSWORD_CHANGED(ADMIN),
    PROFILE_UPDATED(ADMIN),
    PATIENT_REGISTERED_BY_STAFF(ADMIN),

    // Clinic configuration and catalogue.
    DOCTOR_CREATED(ADMIN),
    DOCTOR_UPDATED(ADMIN),
    DOCTOR_DELETED(ADMIN),
    AVAILABILITY_ADDED(ADMIN),
    AVAILABILITY_REMOVED(ADMIN),
    PRODUCT_CREATED(ADMIN),
    PRODUCT_UPDATED(ADMIN),
    PRODUCT_DELETED(ADMIN),
    FORM_QUESTION_CREATED(ADMIN),
    FORM_QUESTION_UPDATED(ADMIN),
    FORM_QUESTION_ACTIVATED(ADMIN),
    FORM_QUESTION_DEACTIVATED(ADMIN),

    // Security events.
    LOGIN_FAILED(SECURITY),
    PERMISSION_DENIED(SECURITY),
    ACCOUNT_LOCKED(SECURITY),
    AUTH_RATE_LIMITED(SECURITY),
    STALE_SESSION_REJECTED(SECURITY),
    ROLE_CHANGE_REJECTED(SECURITY),
    DISABLED_ACCOUNT_REJECTED(SECURITY),
    REFRESH_TOKEN_REJECTED(SECURITY),

    // Retired; kept so old rows load.
    LOGIN(LEGACY),
    LOGOUT(LEGACY),
    CLINICAL_LIST_VIEWED(LEGACY),
    SESSION_STATUS_CHANGED(LEGACY),
    ACCOUNT_STATUS_CHANGED(LEGACY),
    PASSWORD_RESET(LEGACY);

    private final ActivityCategory category;

    ActivityAction(ActivityCategory category) {
        this.category = category;
    }

    public ActivityCategory category() {
        return category;
    }

    public boolean isRetired() {
        return category == LEGACY;
    }
}
