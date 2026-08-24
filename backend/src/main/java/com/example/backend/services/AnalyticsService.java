package com.example.backend.services;

import com.example.backend.dtos.AdminAnalyticsResponse;
import com.example.backend.dtos.AdminAnalyticsResponse.*;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AnalyticsService {

    private final PatientProfileRepository patients;
    private final DoctorProfileRepository doctors;
    private final AppointmentRepository appointments;
    private final AppointmentSessionRepository sessions;
    private final DoctorAvailabilityService availability;
    private final Clock clock;

    private static final ZoneId CLINIC_ZONE = ZoneId.of("Asia/Hebron");

    @Transactional(readOnly = true)
    public AdminAnalyticsResponse calculateAnalytics(Instant from, Instant to) {
        Instant now = clock.instant();
        Instant effectiveTo = to != null ? to : now;
        Instant effectiveFrom = from != null ? from : effectiveTo.minus(30, ChronoUnit.DAYS);

        // Date bounds for "today"
        ZonedDateTime todayStart = now.atZone(CLINIC_ZONE).truncatedTo(ChronoUnit.DAYS);
        Instant todayFrom = todayStart.toInstant();
        Instant todayTo = todayStart.plusDays(1).toInstant();

        // ─────────────────────────────────────────────────────────────────────
        // 1. Overview Data (Live Counts from DB)
        // ─────────────────────────────────────────────────────────────────────
        List<PatientProfile> allPatients = patients.findAllWithUser();
        int totalPatients = allPatients.size();

        List<DoctorProfile> allDoctors = doctors.findAllWithUser();
        int totalDoctors = allDoctors.size();

        List<AppointmentSession> todaySessionsList = sessions.findBetweenWithDetails(todayFrom, todayTo).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .toList();
        int todayAppointmentsCount = todaySessionsList.size();
        int confirmedAppts = (int) todaySessionsList.stream()
                .filter(s -> s.getStatus() == SessionStatus.PLANNED && !s.getStartTime().isBefore(now))
                .count();
        int inRoomAppts = (int) todaySessionsList.stream()
                .filter(s -> s.getStatus() == SessionStatus.PLANNED && s.getStartTime().isBefore(now))
                .count();
        int pendingAppts = confirmedAppts;

        int todaySessionsCount = todaySessionsList.size();
        int completedSessionsCount = (int) todaySessionsList.stream().filter(s -> s.getStatus() == SessionStatus.COMPLETED).count();
        int ongoingSessionsCount = (int) todaySessionsList.stream().filter(s -> s.getStatus() == SessionStatus.PLANNED).count();
        // findBetweenWithDetails has no status filter, so cancelled/no-show rows are
        // still in todaySessionsList above; exclude them wherever a session's presence
        // implies it's actually happening (the live feed, "in session" status).
        List<AppointmentSession> activeTodaySessionsList = todaySessionsList.stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED && s.getStatus() != SessionStatus.NO_SHOW)
                .toList();

        // Calculate patient growth in window vs previous period
        long windowDays = Math.max(1, ChronoUnit.DAYS.between(effectiveFrom, effectiveTo));
        Instant previousPeriodFrom = effectiveFrom.minus(windowDays, ChronoUnit.DAYS);
        long newPatientsInWindow = allPatients.stream()
                .filter(p -> p.getUser().getCreatedAt().isAfter(effectiveFrom) && p.getUser().getCreatedAt().isBefore(effectiveTo))
                .count();
        long newPatientsPrevious = allPatients.stream()
                .filter(p -> p.getUser().getCreatedAt().isAfter(previousPeriodFrom) && p.getUser().getCreatedAt().isBefore(effectiveFrom))
                .count();

        double patientTrendPct = newPatientsPrevious > 0
                ? ((newPatientsInWindow - newPatientsPrevious) * 100.0 / newPatientsPrevious)
                : (newPatientsInWindow > 0 ? 100.0 : 0.0);

        String patientTrendStr = (patientTrendPct >= 0 ? "+" : "") + Math.round(patientTrendPct * 10.0) / 10.0 + "%";
        String patientTrendSub = "+" + newPatientsInWindow + " new in this period";

        ClinicOverviewDto overview = new ClinicOverviewDto(
                totalPatients,
                patientTrendStr,
                patientTrendSub,
                totalDoctors,
                totalDoctors,
                totalDoctors > 0 ? "All suites operating" : "No specialists registered",
                todayAppointmentsCount,
                confirmedAppts,
                inRoomAppts,
                pendingAppts,
                todaySessionsCount,
                completedSessionsCount,
                ongoingSessionsCount
        );

        // ─────────────────────────────────────────────────────────────────────
        // 2. Service Analytics (Completed Sessions Grouped by Treatment)
        // ─────────────────────────────────────────────────────────────────────
        List<AppointmentSession> windowSessions = sessions.findBetweenWithDetails(effectiveFrom, effectiveTo).stream()
                .filter(s -> s.getStatus() == SessionStatus.COMPLETED)
                .toList();
        Map<TreatmentName, List<AppointmentSession>> byTreatment = windowSessions.stream()
                .collect(Collectors.groupingBy(AppointmentSession::getTreatmentName));

        List<ServiceBookingDto> serviceBookings = new ArrayList<>();
        int totalBookingsInWindow = windowSessions.size();

        for (TreatmentName tn : TreatmentName.values()) {
            List<AppointmentSession> sList = byTreatment.getOrDefault(tn, Collections.emptyList());
            int count = sList.size();
            double pct = totalBookingsInWindow > 0 ? (count * 100.0 / totalBookingsInWindow) : 0.0;
            BigDecimal revenue = sList.stream()
                    .map(AppointmentSession::getPriceCharged)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            serviceBookings.add(new ServiceBookingDto(
                    humanize(tn.name()),
                    tn.category().name(),
                    count,
                    Math.round(pct * 10.0) / 10.0,
                    "₪" + revenue.toBigInteger(),
                    iconKeyForCategory(tn.category()),
                    colorHexForCategory(tn.category())
            ));
        }
        serviceBookings.sort((a, b) -> Integer.compare(b.bookingsCount(), a.bookingsCount()));

        String topService = (totalBookingsInWindow > 0 && !serviceBookings.isEmpty() && serviceBookings.get(0).bookingsCount() > 0)
                ? serviceBookings.get(0).serviceName()
                : "None yet";

        List<ServiceGrowthPointDto> serviceGrowth = buildServiceGrowthTimeline(effectiveFrom, effectiveTo, windowSessions);
        ServiceAnalyticsDto serviceAnalytics = new ServiceAnalyticsDto(
                serviceBookings,
                serviceGrowth,
                topService,
                patientTrendStr
        );

        // ─────────────────────────────────────────────────────────────────────
        // 3. Doctor Analytics (Live Practitioner Utilization & Free Slots)
        // ─────────────────────────────────────────────────────────────────────
        List<DoctorUtilizationDto> utilizationList = new ArrayList<>();
        List<DoctorSlotDto> slotList = new ArrayList<>();
        double totalUtilizationSum = 0.0;

        // Estimated available working hours in window (approx 8 hours per weekday)
        double totalAvailableHoursPerDoctor = Math.max(8.0, (windowDays * 8.0 * 5.0 / 7.0));

        for (DoctorProfile doc : allDoctors) {
            String docName = "Dr. " + doc.getUser().getFirstName() + " " + doc.getUser().getLastName();
            String spec = doc.getSpecializations().isEmpty() ? "General Dermatology" : humanize(doc.getSpecializations().iterator().next().name());
            String initials = (doc.getUser().getFirstName().isEmpty() ? "D" : doc.getUser().getFirstName().substring(0, 1))
                    + (doc.getUser().getLastName().isEmpty() ? "R" : doc.getUser().getLastName().substring(0, 1));

            // Sum booked minutes for this practitioner in window
            long bookedMinutes = windowSessions.stream()
                    .filter(s -> s.getPractitioner().getUserId().equals(doc.getUserId()) && s.getStatus() != SessionStatus.CANCELLED)
                    .mapToLong(AppointmentSession::getDurationMinutes)
                    .sum();

            double bookedHours = Math.round((bookedMinutes / 60.0) * 10.0) / 10.0;
            double utilPct = totalAvailableHoursPerDoctor > 0 ? Math.min(100.0, Math.round((bookedHours / totalAvailableHoursPerDoctor * 100.0) * 10.0) / 10.0) : 0.0;
            totalUtilizationSum += utilPct;

            String status = utilPct >= 85.0 ? "High Demand" : (utilPct >= 50.0 ? "Optimal" : (utilPct > 0 ? "Moderate" : "Available"));
            String statusColor = utilPct >= 85.0 ? "#E11D48" : (utilPct >= 50.0 ? "#059669" : "#D97706");

            utilizationList.add(new DoctorUtilizationDto(
                    docName,
                    spec,
                    bookedHours,
                    Math.round(totalAvailableHoursPerDoctor * 10.0) / 10.0,
                    utilPct,
                    status,
                    statusColor
            ));

            // Calculate free slots today
            long todayDoctorSessions = todaySessionsList.stream()
                    .filter(s -> s.getPractitioner().getUserId().equals(doc.getUserId()) && s.getStatus() != SessionStatus.CANCELLED)
                    .count();
            int freeSlots = Math.max(0, 8 - (int) todayDoctorSessions);

            slotList.add(new DoctorSlotDto(
                    docName,
                    spec,
                    initials.toUpperCase(),
                    freeSlots,
                    List.of("11:00", "14:30", "16:00"),
                    freeSlots > 0 ? "Today available" : "Fully booked today",
                    "Suite " + (allDoctors.indexOf(doc) + 101)
            ));
        }

        double averageUtilization = allDoctors.isEmpty() ? 0.0 : Math.round((totalUtilizationSum / allDoctors.size()) * 10.0) / 10.0;
        int totalFreeSlotsToday = slotList.stream().mapToInt(DoctorSlotDto::availableSlotsCount).sum();

        DoctorAnalyticsDto doctorAnalytics = new DoctorAnalyticsDto(
                utilizationList,
                slotList,
                averageUtilization,
                totalFreeSlotsToday
        );

        // ─────────────────────────────────────────────────────────────────────
        // 4. Appointment Analytics (Live Trends, Outcomes & Hourly Peak)
        // ─────────────────────────────────────────────────────────────────────
        List<AppointmentTrendPointDto> trendPoints = buildAppointmentTrendPoints(effectiveFrom, effectiveTo, windowSessions);

        int completedCount = (int) windowSessions.stream().filter(s -> s.getStatus() == SessionStatus.COMPLETED).count();
        int cancelledCount = (int) windowSessions.stream().filter(s -> s.getStatus() == SessionStatus.CANCELLED).count();
        int noShowCount = (int) windowSessions.stream().filter(s -> s.getStatus() == SessionStatus.NO_SHOW).count();

        List<Appointment> windowAppts = appointments.findBetween(effectiveFrom, effectiveTo);
        int rescheduledCount = (int) windowAppts.stream().filter(a -> a.getReplaces() != null).count();
        int outcomeTotal = Math.max(1, completedCount + cancelledCount + noShowCount + rescheduledCount);

        AppointmentOutcomesDto outcomes = new AppointmentOutcomesDto(
                completedCount,
                cancelledCount,
                noShowCount,
                rescheduledCount,
                Math.round((completedCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((cancelledCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((noShowCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((rescheduledCount * 100.0 / outcomeTotal) * 10.0) / 10.0
        );

        // Peak booking hours from session start times
        int morningCount = 0;   // 09:00 - 11:00
        int middayCount = 0;    // 11:00 - 13:00
        int afternoonCount = 0; // 14:00 - 16:00
        int eveningCount = 0;   // 16:00 - 18:00
        int lateCount = 0;      // 18:00 - 20:00

        Map<DayOfWeek, Integer> dayOfWeekCounts = new EnumMap<>(DayOfWeek.class);

        for (AppointmentSession s : windowSessions) {
            ZonedDateTime zdt = s.getStartTime().atZone(CLINIC_ZONE);
            dayOfWeekCounts.merge(zdt.getDayOfWeek(), 1, Integer::sum);
            int hour = zdt.getHour();
            if (hour >= 9 && hour < 11) morningCount++;
            else if (hour >= 11 && hour < 13) middayCount++;
            else if (hour >= 14 && hour < 16) afternoonCount++;
            else if (hour >= 16 && hour < 18) eveningCount++;
            else if (hour >= 18 && hour < 21) lateCount++;
        }

        int maxHourly = Math.max(morningCount, Math.max(middayCount, Math.max(afternoonCount, Math.max(eveningCount, lateCount))));

        List<PeakBookingTimeDto> peakTimes = List.of(
                new PeakBookingTimeDto("09:00 - 11:00", morningCount, maxHourly > 0 && morningCount == maxHourly),
                new PeakBookingTimeDto("11:00 - 13:00", middayCount, maxHourly > 0 && middayCount == maxHourly),
                new PeakBookingTimeDto("14:00 - 16:00", afternoonCount, maxHourly > 0 && afternoonCount == maxHourly),
                new PeakBookingTimeDto("16:00 - 18:00", eveningCount, maxHourly > 0 && eveningCount == maxHourly),
                new PeakBookingTimeDto("18:00 - 20:00", lateCount, maxHourly > 0 && lateCount == maxHourly)
        );

        DayOfWeek busiestDay = dayOfWeekCounts.entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(Map.Entry::getKey)
                .orElse(DayOfWeek.THURSDAY);

        String busiestTimeWindow = maxHourly > 0
                ? (afternoonCount == maxHourly ? "2:00 PM – 4:00 PM" : (eveningCount == maxHourly ? "4:00 PM – 6:00 PM" : "11:00 AM – 1:00 PM"))
                : "N/A";

        double rescheduleRate = outcomeTotal > 0 ? Math.round((rescheduledCount * 100.0 / outcomeTotal) * 10.0) / 10.0 : 0.0;
        RescheduledDto rescheduled = new RescheduledDto(
                rescheduledCount,
                rescheduleRate,
                "",
                List.of()
        );

        AppointmentAnalyticsDto appointmentAnalytics = new AppointmentAnalyticsDto(
                trendPoints,
                outcomes,
                peakTimes,
                humanize(busiestDay.name()),
                busiestTimeWindow,
                rescheduled
        );

        // ─────────────────────────────────────────────────────────────────────
        // 5. Patient Analytics (Live Registration & Retention Rates)
        // ─────────────────────────────────────────────────────────────────────
        Set<UUID> uniquePatientsInWindow = windowSessions.stream()
                .map(AppointmentSession::getPatientUserId)
                .collect(Collectors.toSet());

        int activePatientsCount = uniquePatientsInWindow.size();
        int newPatientCountInWindow = (int) allPatients.stream()
                .filter(p -> p.getUser().getCreatedAt().isAfter(effectiveFrom) && p.getUser().getCreatedAt().isBefore(effectiveTo))
                .count();
        int returningPatientCountInWindow = Math.max(0, activePatientsCount - newPatientCountInWindow);
        int ratioTotal = Math.max(1, newPatientCountInWindow + returningPatientCountInWindow);

        PatientRatioDto ratio = new PatientRatioDto(
                newPatientCountInWindow,
                returningPatientCountInWindow,
                Math.round((newPatientCountInWindow * 100.0 / ratioTotal) * 10.0) / 10.0,
                Math.round((returningPatientCountInWindow * 100.0 / ratioTotal) * 10.0) / 10.0
        );

        List<PatientGrowthPointDto> patientGrowth = buildPatientGrowthTimeline(allPatients, effectiveFrom, effectiveTo);

        // Calculate repeat booking / retention
        Map<UUID, Long> visitsPerPatient = windowSessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.COMPLETED)
                .collect(Collectors.groupingBy(AppointmentSession::getPatientUserId, Collectors.counting()));

        long repeatPatients = visitsPerPatient.values().stream().filter(v -> v >= 2).count();
        long loyaltyPatients = visitsPerPatient.values().stream().filter(v -> v >= 3).count();
        double retentionRate = visitsPerPatient.isEmpty() ? 0.0 : Math.round((repeatPatients * 100.0 / visitsPerPatient.size()) * 10.0) / 10.0;
        double repeatRate = visitsPerPatient.isEmpty() ? 0.0 : Math.round((repeatPatients * 100.0 / visitsPerPatient.size()) * 10.0) / 10.0;

        PatientRetentionDto retention = new PatientRetentionDto(
                retentionRate,
                retentionRate > 0 ? 24 : 0,
                repeatRate,
                (int) loyaltyPatients,
                patientTrendStr
        );

        PatientAnalyticsDto patientAnalytics = new PatientAnalyticsDto(
                ratio,
                patientGrowth,
                retention
        );

        // ─────────────────────────────────────────────────────────────────────
        // 6. Live Daily Operations (Today's Real Appointments & Active Staff)
        // ─────────────────────────────────────────────────────────────────────
        DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm");
        List<TodayAppointmentItemDto> todayAppointmentItems = new ArrayList<>();
        for (AppointmentSession s : activeTodaySessionsList) {
            ZonedDateTime zdt = s.getStartTime().atZone(CLINIC_ZONE);
            String time = timeFormatter.format(zdt);
            String patientName = s.getAppointment().getPatient().getUser().getFirstName() + " " + s.getAppointment().getPatient().getUser().getLastName();
            String txName = humanize(s.getTreatmentName().name());
            String docName = "Dr. " + s.getPractitioner().getUser().getFirstName();
            String status = s.getStatus() == SessionStatus.COMPLETED ? "Completed"
                    : (s.getStartTime().isBefore(now) ? "In Room" : "Confirmed");

            todayAppointmentItems.add(new TodayAppointmentItemDto(
                    s.getId().toString(),
                    s.getAppointment().getPatient().getUserId().toString(),
                    time,
                    patientName,
                    txName,
                    docName,
                    status
            ));
        }

        LocalTime nowTime = now.atZone(CLINIC_ZONE).toLocalTime();
        Map<UUID, List<TimeRange>> todaysWindows = availability.openWindowsOn(
                allDoctors.stream().map(DoctorProfile::getUserId).toList(),
                todayStart.toLocalDate());

        List<StaffDutyItemDto> staffList = new ArrayList<>();
        for (DoctorProfile doc : allDoctors) {
            String docName = "Dr. " + doc.getUser().getFirstName() + " " + doc.getUser().getLastName();
            // The account's actual role, not a specialization guess.
            String role = "Doctor";
            long apptsToday = activeTodaySessionsList.stream()
                    .filter(s -> s.getPractitioner().getUserId().equals(doc.getUserId()))
                    .count();
            boolean hasSessionNow = activeTodaySessionsList.stream()
                    .anyMatch(s -> s.getPractitioner().getUserId().equals(doc.getUserId()) && s.getStartTime().isBefore(now) && s.getEndTime().isAfter(now));
            // "Available" means actually within a configured availability window right
            // now - recurring rules set up in the past (open-ended or not) and
            // overrides whose date range spans today both resolve into
            // todaysWindows via the same openWindowsOn used to gate real bookings.
            // A doctor between sessions or on a break is neither in a session nor
            // truly available, and status is never inferred from appointment counts.
            boolean withinAvailabilityNow = todaysWindows.getOrDefault(doc.getUserId(), List.of())
                    .stream()
                    .anyMatch(window -> window.covers(nowTime, nowTime));
            String status = dutyStatus(hasSessionNow, withinAvailabilityNow);

            staffList.add(new StaffDutyItemDto(
                    doc.getUserId(),
                    docName,
                    role,
                    (int) apptsToday,
                    status,
                    true
            ));
        }

        OperationsDataDto operations = new OperationsDataDto(
                todayAppointmentItems,
                staffList
        );

        return new AdminAnalyticsResponse(
                "custom",
                effectiveFrom,
                effectiveTo,
                overview,
                serviceAnalytics,
                doctorAnalytics,
                appointmentAnalytics,
                patientAnalytics,
                operations
        );
    }

    private List<ServiceGrowthPointDto> buildServiceGrowthTimeline(Instant from, Instant to, List<AppointmentSession> sessionList) {
        List<ServiceGrowthPointDto> points = new ArrayList<>();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("d MMM");
        ZonedDateTime start = from.atZone(CLINIC_ZONE);
        long daysBetween = Math.max(1, ChronoUnit.DAYS.between(from, to));
        int steps = Math.min(6, (int) daysBetween);
        long intervalDays = Math.max(1, daysBetween / steps);

        for (int i = 0; i <= steps; i++) {
            ZonedDateTime stepDateStart = start.plusDays(i * intervalDays);
            ZonedDateTime stepDateEnd = stepDateStart.plusDays(intervalDays);
            Instant sliceFrom = stepDateStart.toInstant();
            Instant sliceTo = stepDateEnd.toInstant();

            long laser = sessionList.stream()
                    .filter(s -> s.getCategory() == TreatmentCategory.LASER && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();
            long facial = sessionList.stream()
                    .filter(s -> s.getCategory() == TreatmentCategory.FACIAL && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();
            long contour = sessionList.stream()
                    .filter(s -> s.getCategory() == TreatmentCategory.BODY && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();
            long injectable = sessionList.stream()
                    .filter(s -> s.getCategory() == TreatmentCategory.INJECTABLE && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();

            points.add(new ServiceGrowthPointDto(
                    formatter.format(stepDateStart),
                    (double) laser,
                    (double) facial,
                    (double) contour,
                    (double) injectable
            ));
        }
        return points;
    }

    private List<AppointmentTrendPointDto> buildAppointmentTrendPoints(Instant from, Instant to, List<AppointmentSession> sessionList) {
        List<AppointmentTrendPointDto> points = new ArrayList<>();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("d MMM");
        ZonedDateTime start = from.atZone(CLINIC_ZONE);
        long daysBetween = Math.max(1, ChronoUnit.DAYS.between(from, to));
        int steps = Math.min(6, (int) daysBetween);
        long intervalDays = Math.max(1, daysBetween / steps);

        for (int i = 0; i <= steps; i++) {
            ZonedDateTime stepDateStart = start.plusDays(i * intervalDays);
            ZonedDateTime stepDateEnd = stepDateStart.plusDays(intervalDays);
            Instant sliceFrom = stepDateStart.toInstant();
            Instant sliceTo = stepDateEnd.toInstant();

            long booked = sessionList.stream()
                    .filter(s -> s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();
            long completed = sessionList.stream()
                    .filter(s -> s.getStatus() == SessionStatus.COMPLETED && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();
            long cancelled = sessionList.stream()
                    .filter(s -> s.getStatus() == SessionStatus.CANCELLED && s.getStartTime().isAfter(sliceFrom) && s.getStartTime().isBefore(sliceTo))
                    .count();

            points.add(new AppointmentTrendPointDto(
                    formatter.format(stepDateStart),
                    (double) booked,
                    (double) completed,
                    (double) cancelled
            ));
        }
        return points;
    }

    private List<PatientGrowthPointDto> buildPatientGrowthTimeline(List<PatientProfile> allPatients, Instant from, Instant to) {
        List<PatientGrowthPointDto> points = new ArrayList<>();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("d MMM");
        ZonedDateTime start = from.atZone(CLINIC_ZONE);
        long daysBetween = Math.max(1, ChronoUnit.DAYS.between(from, to));
        int steps = Math.min(6, (int) daysBetween);
        long intervalDays = Math.max(1, daysBetween / steps);

        for (int i = 0; i <= steps; i++) {
            ZonedDateTime stepDate = start.plusDays(i * intervalDays);
            Instant slicePoint = stepDate.toInstant();

            long cumulative = allPatients.stream()
                    .filter(p -> p.getUser().getCreatedAt().isBefore(slicePoint))
                    .count();
            long newInSlice = allPatients.stream()
                    .filter(p -> p.getUser().getCreatedAt().isAfter(slicePoint.minus(intervalDays, ChronoUnit.DAYS)) && p.getUser().getCreatedAt().isBefore(slicePoint))
                    .count();

            points.add(new PatientGrowthPointDto(
                    formatter.format(stepDate),
                    (double) cumulative,
                    (double) newInSlice
            ));
        }
        return points;
    }

    private static String humanize(String text) {
        if (text == null || text.isEmpty()) return "";
        String[] words = text.replace('_', ' ').toLowerCase().split(" ");
        StringBuilder sb = new StringBuilder();
        for (String w : words) {
            if (!w.isEmpty()) {
                sb.append(Character.toUpperCase(w.charAt(0))).append(w.substring(1)).append(" ");
            }
        }
        return sb.toString().trim();
    }

    private static String iconKeyForCategory(TreatmentCategory cat) {
        return switch (cat) {
            case FACIAL -> "spa";
            case LASER -> "flare";
            case INJECTABLE -> "medication";
            case BODY -> "accessibility_new";
            case CONSULTATION -> "forum";
        };
    }

    private static String colorHexForCategory(TreatmentCategory cat) {
        return switch (cat) {
            case FACIAL -> "#E11D48"; // Rose
            case LASER -> "#D97706"; // Gold
            case INJECTABLE -> "#7C3AED"; // Lav
            case BODY -> "#059669"; // Sage
            case CONSULTATION -> "#2563EB"; // Blue
        };
    }

    // Shared with the "Staff Today" list, so the two surfaces never disagree.
    private static String dutyStatus(boolean hasSessionNow, boolean withinAvailabilityNow) {
        return hasSessionNow ? "In Session" : (withinAvailabilityNow ? "Available" : "Off Duty");
    }

    // A single doctor's live status, cheap enough to call from a detail view
    // without pulling the full admin analytics aggregate.
    @Transactional(readOnly = true)
    public com.example.backend.dtos.DoctorStatusResponse getDoctorStatus(UUID doctorUserId) {
        Instant now = clock.instant();
        ZonedDateTime todayStart = now.atZone(CLINIC_ZONE).truncatedTo(ChronoUnit.DAYS);
        Instant todayFrom = todayStart.toInstant();
        Instant todayTo = todayStart.plusDays(1).toInstant();
        LocalTime nowTime = now.atZone(CLINIC_ZONE).toLocalTime();

        List<AppointmentSession> todaySessions = sessions
                .findForPractitionerBetweenWithDetails(doctorUserId, todayFrom, todayTo).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED && s.getStatus() != SessionStatus.NO_SHOW)
                .toList();

        boolean hasSessionNow = todaySessions.stream()
                .anyMatch(s -> s.getStartTime().isBefore(now) && s.getEndTime().isAfter(now));
        boolean withinAvailabilityNow = availability.openWindowsOn(doctorUserId, todayStart.toLocalDate())
                .stream()
                .anyMatch(window -> window.covers(nowTime, nowTime));

        return new com.example.backend.dtos.DoctorStatusResponse(
                dutyStatus(hasSessionNow, withinAvailabilityNow),
                todaySessions.size());
    }

    @Transactional(readOnly = true)
    public com.example.backend.dtos.DoctorAnalyticsResponse calculateDoctorAnalytics(UUID doctorId, Instant from, Instant to) {
        Instant now = clock.instant();
        Instant effectiveTo = to != null ? to : now;
        Instant effectiveFrom = from != null ? from : effectiveTo.minus(30, ChronoUnit.DAYS);

        // Date bounds for "today"
        ZonedDateTime todayStart = now.atZone(CLINIC_ZONE).truncatedTo(ChronoUnit.DAYS);
        Instant todayFrom = todayStart.toInstant();
        Instant todayTo = todayStart.plusDays(1).toInstant();

        // 1. Active Patients Counts (related to doctor)
        int activePatientsCount = sessions.countActivePatients(doctorId);
        int todayPatientsCount = sessions.countActivePatientsBetween(doctorId, todayFrom, todayTo);

        // Fetch sessions for this doctor in date range
        List<AppointmentSession> doctorSessions = sessions.findForPractitionerBetweenWithDetails(doctorId, effectiveFrom, effectiveTo);

        // 2. Appointments Over Time
        // Group doctorSessions by day in window
        long daysBetween = Math.max(1, ChronoUnit.DAYS.between(effectiveFrom, effectiveTo));
        Map<String, Integer> dateCounts = new LinkedHashMap<>();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("d MMM").withZone(CLINIC_ZONE);
        
        for (long i = 0; i <= daysBetween; i++) {
            String label = formatter.format(effectiveFrom.plus(i, ChronoUnit.DAYS));
            dateCounts.put(label, 0);
        }
        for (AppointmentSession s : doctorSessions) {
            if (s.getStatus() != SessionStatus.COMPLETED) continue;
            String label = formatter.format(s.getStartTime());
            dateCounts.merge(label, 1, Integer::sum);
        }
        List<com.example.backend.dtos.DoctorAnalyticsResponse.AppointmentTrendPointDto> appointmentsOverTime = dateCounts.entrySet().stream()
                .map(e -> new com.example.backend.dtos.DoctorAnalyticsResponse.AppointmentTrendPointDto(e.getKey(), e.getValue()))
                .toList();

        // 3. Appointment Outcomes (Completed / Cancelled / No-show / Rescheduled) for doctor's sessions
        int completedCount = (int) doctorSessions.stream().filter(s -> s.getStatus() == SessionStatus.COMPLETED).count();
        int cancelledCount = (int) doctorSessions.stream().filter(s -> s.getStatus() == SessionStatus.CANCELLED).count();
        int noShowCount = (int) doctorSessions.stream().filter(s -> s.getStatus() == SessionStatus.NO_SHOW).count();
        
        // Rescheduled is where parent appointment has replacements
        int rescheduledCount = (int) doctorSessions.stream()
                .map(AppointmentSession::getAppointment)
                .distinct()
                .filter(a -> a.getReplaces() != null)
                .count();
                
        int outcomeTotal = Math.max(1, completedCount + cancelledCount + noShowCount + rescheduledCount);
        
        com.example.backend.dtos.DoctorAnalyticsResponse.AppointmentOutcomesDto outcomes =
            new com.example.backend.dtos.DoctorAnalyticsResponse.AppointmentOutcomesDto(
                completedCount,
                cancelledCount,
                noShowCount,
                rescheduledCount,
                Math.round((completedCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((cancelledCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((noShowCount * 100.0 / outcomeTotal) * 10.0) / 10.0,
                Math.round((rescheduledCount * 100.0 / outcomeTotal) * 10.0) / 10.0
            );

        // 4. Treatments Performed
        // Group completed sessions by treatment name.
        List<AppointmentSession> completedDoctorSessions = doctorSessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.COMPLETED)
                .toList();
        Map<TreatmentName, List<AppointmentSession>> byTreatment = completedDoctorSessions.stream()
                .collect(Collectors.groupingBy(AppointmentSession::getTreatmentName));

        int totalBookings = Math.max(1, completedDoctorSessions.size());

        List<com.example.backend.dtos.DoctorAnalyticsResponse.ServiceBookingDto> treatmentsPerformed = byTreatment.entrySet().stream()
                .map(e -> {
                    TreatmentName tName = e.getKey();
                    List<AppointmentSession> list = e.getValue();
                    int count = list.size();
                    BigDecimal totalRev = list.stream()
                            .map(AppointmentSession::getPriceCharged)
                            .reduce(BigDecimal.ZERO, BigDecimal::add);

                    double pct = Math.round((count * 100.0 / totalBookings) * 10.0) / 10.0;
                    String revenueStr = "₪" + String.format("%,d", totalRev.intValue());
                    
                    return new com.example.backend.dtos.DoctorAnalyticsResponse.ServiceBookingDto(
                            humanize(tName.name()),
                            tName.category().name(),
                            count,
                            pct,
                            revenueStr,
                            iconKeyForCategory(tName.category()),
                            colorHexForCategory(tName.category())
                    );
                })
                .sorted(Comparator.comparingInt(com.example.backend.dtos.DoctorAnalyticsResponse.ServiceBookingDto::bookingsCount).reversed())
                .toList();

        // 5. Today's Appointments with status (using doctorSessions for today)
        List<AppointmentSession> todaySessions = sessions.findForPractitionerBetweenWithDetails(doctorId, todayFrom, todayTo).stream()
                .filter(s -> s.getStatus() == AppointmentSession.SessionStatus.PLANNED)
                .toList();
        DateTimeFormatter timeFormatter = DateTimeFormatter.ofPattern("HH:mm").withZone(CLINIC_ZONE);
        DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("EEEE, d MMM").withZone(CLINIC_ZONE);

        List<com.example.backend.dtos.DoctorAnalyticsResponse.DoctorAppointmentDto> todayAppointments = todaySessions.stream()
                .map(s -> {
                    Appointment appt = s.getAppointment();
                    String patName = appt.getPatient().getUser().getFirstName() + " " + appt.getPatient().getUser().getLastName();
                    return new com.example.backend.dtos.DoctorAnalyticsResponse.DoctorAppointmentDto(
                            appt.getId().toString(),
                            appt.getPatient().getUserId().toString(),
                            timeFormatter.format(s.getStartTime()),
                            patName,
                            humanize(s.getTreatmentName().name()),
                            s.getPractitioner().getUser().getFirstName() + " " + s.getPractitioner().getUser().getLastName(),
                            s.getStatus().name(),
                            dateFormatter.format(s.getStartTime())
                    );
                })
                .toList();

        // 6. Upcoming Appointments (using doctorSessions from now onwards)
        List<AppointmentSession> upcomingSessions = sessions.findForPractitionerBetweenWithDetails(doctorId, now, now.plus(30, ChronoUnit.DAYS));
        List<com.example.backend.dtos.DoctorAnalyticsResponse.DoctorAppointmentDto> upcomingAppointments = upcomingSessions.stream()
                .map(s -> {
                    Appointment appt = s.getAppointment();
                    String patName = appt.getPatient().getUser().getFirstName() + " " + appt.getPatient().getUser().getLastName();
                    return new com.example.backend.dtos.DoctorAnalyticsResponse.DoctorAppointmentDto(
                            appt.getId().toString(),
                            appt.getPatient().getUserId().toString(),
                            timeFormatter.format(s.getStartTime()),
                            patName,
                            humanize(s.getTreatmentName().name()),
                            s.getPractitioner().getUser().getFirstName() + " " + s.getPractitioner().getUser().getLastName(),
                            s.getStatus().name(),
                            dateFormatter.format(s.getStartTime())
                    );
                })
                .toList();

        return new com.example.backend.dtos.DoctorAnalyticsResponse(
                activePatientsCount,
                todayPatientsCount,
                appointmentsOverTime,
                outcomes,
                treatmentsPerformed,
                todayAppointments,
                upcomingAppointments
        );
    }
}
