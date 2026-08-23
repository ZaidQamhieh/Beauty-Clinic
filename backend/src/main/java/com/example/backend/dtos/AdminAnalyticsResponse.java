package com.example.backend.dtos;

import java.time.Instant;
import java.util.List;

public record AdminAnalyticsResponse(
        String rangeType,
        Instant startDate,
        Instant endDate,
        ClinicOverviewDto overview,
        ServiceAnalyticsDto serviceAnalytics,
        DoctorAnalyticsDto doctorAnalytics,
        AppointmentAnalyticsDto appointmentAnalytics,
        PatientAnalyticsDto patientAnalytics,
        OperationsDataDto operations
) {
    public record ClinicOverviewDto(
            int totalPatients,
            String patientTrend,
            String patientTrendSub,
            int totalDoctors,
            int activeDoctorsNow,
            String doctorSub,
            int todayAppointments,
            int confirmedAppointments,
            int inRoomAppointments,
            int pendingAppointments,
            int todaySessions,
            int completedSessions,
            int ongoingSessions
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

    public record ServiceGrowthPointDto(
            String dateLabel,
            double laserCount,
            double facialCount,
            double contourCount,
            double injectableCount
    ) {}

    public record ServiceAnalyticsDto(
            List<ServiceBookingDto> bookingsByService,
            List<ServiceGrowthPointDto> growthOverTime,
            String topService,
            String growthPercentage
    ) {}

    public record DoctorUtilizationDto(
            String doctorName,
            String specialty,
            double bookedHours,
            double totalAvailableHours,
            double utilizationPercentage,
            String status,
            String statusColorHex
    ) {}

    public record DoctorSlotDto(
            String doctorName,
            String specialty,
            String avatarInitials,
            int availableSlotsCount,
            List<String> slots,
            String nextAvailable,
            String room
    ) {}

    public record DoctorAnalyticsDto(
            List<DoctorUtilizationDto> utilizationList,
            List<DoctorSlotDto> availableSlotsList,
            double averageUtilization,
            int totalFreeSlotsToday
    ) {}

    public record AppointmentTrendPointDto(
            String dateLabel,
            double booked,
            double completed,
            double cancelled
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

    public record PeakBookingTimeDto(
            String timeSlot,
            int bookingVolume,
            boolean isPeak
    ) {}

    public record RescheduledReasonDto(
            String reason,
            int count,
            double percentage
    ) {}

    public record RescheduledDto(
            int totalRescheduled,
            double rescheduleRate,
            String avgNoticeTime,
            List<RescheduledReasonDto> topReasons
    ) {}

    public record AppointmentAnalyticsDto(
            List<AppointmentTrendPointDto> bookingsOverTime,
            AppointmentOutcomesDto outcomes,
            List<PeakBookingTimeDto> peakBookingTimes,
            String busiestDayOfWeek,
            String busiestTimeWindow,
            RescheduledDto rescheduled
    ) {}

    public record PatientRatioDto(
            int newPatients,
            int returningPatients,
            double newPercentage,
            double returningPercentage
    ) {}

    public record PatientGrowthPointDto(
            String dateLabel,
            double totalCumulative,
            double monthlyNew
    ) {}

    public record PatientRetentionDto(
            double retentionRate,
            int averageReturnDays,
            double repeatBookingRate,
            int activeLoyaltyMembers,
            String retentionTrend
    ) {}

    public record PatientAnalyticsDto(
            PatientRatioDto newVsReturning,
            List<PatientGrowthPointDto> growthTimeline,
            PatientRetentionDto retention
    ) {}

    public record TodayAppointmentItemDto(
            String id,
            String patientId,
            String time,
            String patientName,
            String treatmentName,
            String doctorName,
            String status
    ) {}

    public record StaffDutyItemDto(
            String name,
            String role,
            int appointmentsCount,
            String status,
            boolean isDoctor
    ) {}

    public record OperationsDataDto(
            List<TodayAppointmentItemDto> todayAppointments,
            List<StaffDutyItemDto> staffList
    ) {}
}
