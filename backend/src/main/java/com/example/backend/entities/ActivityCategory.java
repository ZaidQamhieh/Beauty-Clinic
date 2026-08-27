package com.example.backend.entities;

// Retention and visibility both follow this.
public enum ActivityCategory {
    CLINICAL,
    ADMIN,
    SECURITY,
    // Never emitted; only rows already written.
    LEGACY
}
