package com.example.backend.entities;

// The column is a plain varchar with no CHECK, so this list grows without a migration.
public enum ActivityAction {
    LOGIN,
    LOGOUT,
    LOGIN_FAILED,
    ACCOUNT_REGISTERED,
    PERMISSION_DENIED,
    APPOINTMENT_BOOKED,
    APPOINTMENT_RESCHEDULED,
    APPOINTMENT_CANCELLED,
    SESSION_SCHEDULED,
    // Kept for rows already written; new work names the status it moved to.
    SESSION_STATUS_CHANGED,
    SESSION_CANCELLED,
    SESSION_COMPLETED,
    SESSION_NO_SHOW,
    CLINICAL_PROFILE_UPDATED
}
