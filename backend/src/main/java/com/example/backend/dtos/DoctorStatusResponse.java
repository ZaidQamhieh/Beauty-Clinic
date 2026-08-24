package com.example.backend.dtos;

// "In Session" | "Available" | "Off Duty" - see AnalyticsService.dutyStatus.
public record DoctorStatusResponse(
        String status,
        int appointmentsToday
) {
}
