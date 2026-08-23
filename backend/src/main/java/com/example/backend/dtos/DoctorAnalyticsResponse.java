package com.example.backend.dtos;

import java.time.Instant;
import java.util.List;

public record DoctorAnalyticsResponse(
        int activePatientsCount,
        int todayPatientsCount,
        List<AppointmentTrendPointDto> appointmentsOverTime,
        AppointmentOutcomesDto appointmentOutcomes,
        List<ServiceBookingDto> treatmentsPerformed,
        List<DoctorAppointmentDto> todayAppointments,
        List<DoctorAppointmentDto> upcomingAppointments
) {
    public record AppointmentTrendPointDto(
            String dateLabel,
            int count
    ) {}

    public record AppointmentOutcomesDto(
            int completed,
            int cancelled,
            int noShow,
            int rescheduled,
            double completedRate,
            double cancelledRate,
            double noShowRate,
            double rescheduledRate
    ) {}

    public record ServiceBookingDto(
            String serviceName,
            String category,
            int bookingsCount,
            double percentage,
            String revenue,
            String iconKey,
            String accentColorHex
    ) {}

    public record DoctorAppointmentDto(
            String appointmentId,
            String patientId,
            String time,
            String patientName,
            String treatmentName,
            String doctorName,
            String status,
            String date
    ) {}
}
