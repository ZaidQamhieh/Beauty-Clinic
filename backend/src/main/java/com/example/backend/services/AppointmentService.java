package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.dtos.RescheduleAppointmentRequest;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.PatientProfile;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

// The visit. Treatments belong to AppointmentSessionService, never built here.
@Service
@RequiredArgsConstructor
public class AppointmentService {

    private final AppointmentRepository appointments;
    private final AppointmentSessionRepository sessions;
    private final AppointmentSessionService sessionService;
    private final DoctorAvailabilityService availability;
    private final PatientProfileRepository patients;
    private final DoctorProfileRepository doctors;
    private final UserAccountRepository users;
    private final CurrentUser currentUser;
    private final ClinicProperties clinic;
    private final ActivityLogService activityLogs;

    @Transactional
    public AppointmentResponse book(BookAppointmentRequest request) {
        // Tag admits doctor, admin and patient. Patient limited to themselves.
        if (currentUser.hasRole(Role.PATIENT) && !currentUser.is(request.patientUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Patients may only book for themselves");
        }

        PatientProfile patient = patients.findById(request.patientUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));

        Appointment appointment = new Appointment(patient, request.session().startTime());
        currentUser.id().ifPresent(id -> appointment.setCreatedBy(users.getReferenceById(id)));
        appointments.save(appointment);

        AppointmentSession session = sessionService.schedule(appointment, request.session());
        record(ActivityAction.APPOINTMENT_BOOKED, appointment);

        return AppointmentResponse.of(appointment, List.of(AppointmentSessionResponse.of(session)));
    }

    @Transactional
    public AppointmentResponse reschedule(UUID id, RescheduleAppointmentRequest request) {
        Appointment original = require(id);
        assertBooked(original);

        // Only unstarted work moves; COMPLETED or NO_SHOW stays, with its clinical record.
        List<AppointmentSession> moving = sessions.findByAppointmentId(original.getId()).stream()
                .filter(s -> s.getStatus() == SessionStatus.PLANNED)
                .toList();

        Duration delta = Duration.between(original.getScheduledAt(), request.startTime());

        // Cancel must hit the database first: Hibernate flushes inserts before updates.
        original.cancel();
        moving.forEach(s -> s.setStatus(SessionStatus.CANCELLED));
        appointments.flush();

        Appointment replacement = new Appointment(original.getPatient(), request.startTime());
        replacement.setCreatedBy(original.getCreatedBy());
        replacement.setReplaces(original);
        appointments.save(replacement);

        List<AppointmentSessionResponse> rebuilt = moving.stream()
                .map(s -> AppointmentSessionResponse.of(
                        sessionService.schedule(replacement, movedBy(s, delta), originalTariff(s))))
                .toList();

        // Logged against the replacement, which is the row that now exists.
        record(ActivityAction.APPOINTMENT_RESCHEDULED, replacement);

        return AppointmentResponse.of(replacement, rebuilt);
    }

    @Transactional
    public AppointmentResponse cancel(UUID id) {
        Appointment appointment = require(id);
        assertBooked(appointment);
        assertNotStarted(appointment);
        appointment.cancel();

        sessions.findByAppointmentId(id).stream()
                .filter(s -> s.getStatus() == SessionStatus.PLANNED)
                .forEach(s -> s.setStatus(SessionStatus.CANCELLED));

        record(ActivityAction.APPOINTMENT_CANCELLED, appointment);

        return withSessions(appointment);
    }

    @Transactional(readOnly = true)
    public AppointmentResponse read(UUID id) {
        return withSessions(require(id));
    }

    @Transactional(readOnly = true)
    public Page<AppointmentResponse> readOwnAsPatient(Pageable pageable) {
        return withSessions(
                appointments.findByPatientUserIdOrderByScheduledAtAsc(currentUser.requireId(), pageable));
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readOwnSchedule(LocalDate date) {
        return scheduleFor(currentUser.requireId(), date);
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> readSchedule(UUID doctorId, LocalDate date) {
        if (doctorId != null) {
            return scheduleFor(doctorId, date);
        }

        LocalDate day = dayOrToday(date);
        return sorted(appointments.findBetween(startOfDay(day), startOfDay(day.plusDays(1))));
    }

    // Asked per treatment, not per length: how long it runs is the treatment's own property.
    @Transactional(readOnly = true)
    public List<FreeSlotResponse> freeSlots(UUID doctorId, TreatmentName treatmentName, LocalDate date) {
        if (!doctors.existsById(doctorId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor");
        }

        Duration duration = Duration.ofMinutes(clinic.tariffFor(treatmentName).durationMinutes());

        // Every status but CANCELLED holds its slot, matching the constraint.
        List<AppointmentSession> busy = sessionsFor(doctorId, date).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .toList();

        return availability.openWindowsOn(doctorId, date).stream()
                .flatMap(window -> slotsWithin(date, window, duration, busy).stream())
                .sorted(Comparator.comparing(FreeSlotResponse::startTime))
                .toList();
    }

    // Same treatment, practitioner and length, shifted by the delta; no length is being chosen.
    private AddSessionRequest movedBy(AppointmentSession session, Duration delta) {
        return new AddSessionRequest(
                session.getPractitioner().getUserId(),
                session.getTreatmentName(),
                session.getStartTime().plus(delta),
                session.getDurationMinutes()
        );
    }

    // What the session was sold at, not what the same treatment costs today.
    private Tariff originalTariff(AppointmentSession session) {
        return new Tariff(session.getPriceCharged(), session.getDurationMinutes());
    }

    // Who changed which visit, for whom. The actor is absent for work with no caller.
    private void record(ActivityAction action, Appointment appointment) {
        activityLogs.recordAppointment(
                currentUser.id().orElse(null),
                appointment.getPatient().getUserId(),
                action,
                appointment.getId());
    }

    // Walks each free stretch from its own start; striding one anchor blanked the whole step.
    private List<FreeSlotResponse> slotsWithin(
            LocalDate date, DoctorAvailability window, Duration duration, List<AppointmentSession> busy
    ) {
        Instant windowStart = date.atTime(window.getStartTime()).atZone(clinic.zone()).toInstant();
        Instant windowEnd = date.atTime(window.getEndTime()).atZone(clinic.zone()).toInstant();

        List<FreeSlotResponse> free = new ArrayList<>();

        for (Instant[] gap : gapsIn(windowStart, windowEnd, busy)) {
            Instant cursor = gap[0];
            while (!cursor.plus(duration).isAfter(gap[1])) {
                free.add(new FreeSlotResponse(cursor, cursor.plus(duration)));
                cursor = cursor.plus(duration);
            }
        }

        return free;
    }

    // The window minus everything holding time in it, as [start, end) pairs.
    private List<Instant[]> gapsIn(Instant windowStart, Instant windowEnd, List<AppointmentSession> busy) {
        List<AppointmentSession> overlapping = busy.stream()
                .filter(s -> s.getStartTime().isBefore(windowEnd) && s.getEndTime().isAfter(windowStart))
                .sorted(Comparator.comparing(AppointmentSession::getStartTime))
                .toList();

        List<Instant[]> gaps = new ArrayList<>();
        Instant cursor = windowStart;

        for (AppointmentSession taken : overlapping) {
            if (taken.getStartTime().isAfter(cursor)) {
                gaps.add(new Instant[]{cursor, taken.getStartTime()});
            }
            // Bookings can overlap each other across doctors, so never walk backwards.
            if (taken.getEndTime().isAfter(cursor)) {
                cursor = taken.getEndTime();
            }
        }

        if (cursor.isBefore(windowEnd)) {
            gaps.add(new Instant[]{cursor, windowEnd});
        }

        return gaps;
    }

    // Deduped by id: Appointment has no equals, so distinct() would rely on identity.
    private List<AppointmentResponse> scheduleFor(UUID doctorUserId, LocalDate date) {
        Map<UUID, Appointment> visits = new LinkedHashMap<>();
        sessionsFor(doctorUserId, dayOrToday(date))
                .forEach(s -> visits.putIfAbsent(s.getAppointment().getId(), s.getAppointment()));

        return sorted(List.copyOf(visits.values()));
    }

    private List<AppointmentSession> sessionsFor(UUID doctorUserId, LocalDate date) {
        return sessions.findForPractitionerBetween(
                doctorUserId, startOfDay(date), startOfDay(date.plusDays(1)));
    }

    private void assertBooked(Appointment appointment) {
        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }
    }

    // No notice period, but a visit already under way is undone per session, not cancelled.
    private void assertNotStarted(Appointment appointment) {
        if (!appointment.getScheduledAt().isAfter(Instant.now())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That appointment has already started");
        }
    }

    private LocalDate dayOrToday(LocalDate date) {
        if (date != null) {
            return date;
        }
        return LocalDate.now(clinic.zone());
    }

    private Instant startOfDay(LocalDate date) {
        return date.atStartOfDay(clinic.zone()).toInstant();
    }

    private AppointmentResponse withSessions(Appointment appointment) {
        return AppointmentResponse.of(appointment, sessions.findByAppointmentId(appointment.getId()).stream()
                .map(AppointmentSessionResponse::of)
                .toList());
    }

    private List<AppointmentResponse> sorted(List<Appointment> found) {
        Map<UUID, List<AppointmentSessionResponse>> byAppointment = sessionsFor(found);

        return found.stream()
                .map(a -> AppointmentResponse.of(a, byAppointment.getOrDefault(a.getId(), List.of())))
                .sorted(Comparator.comparing(AppointmentResponse::scheduledAt))
                .toList();
    }

    // Already ordered by the query, so the page keeps its own sequence.
    private Page<AppointmentResponse> withSessions(Page<Appointment> page) {
        Map<UUID, List<AppointmentSessionResponse>> byAppointment = sessionsFor(page.getContent());

        return page.map(a -> AppointmentResponse.of(a, byAppointment.getOrDefault(a.getId(), List.of())));
    }

    // Sessions for the whole page in one query, not one query per appointment.
    private Map<UUID, List<AppointmentSessionResponse>> sessionsFor(List<Appointment> found) {
        if (found.isEmpty()) {
            return Map.of();
        }

        return sessions.findByAppointmentIdIn(found.stream().map(Appointment::getId).toList()).stream()
                .collect(Collectors.groupingBy(
                        s -> s.getAppointment().getId(),
                        Collectors.mapping(AppointmentSessionResponse::of, Collectors.toList())));
    }

    private Appointment require(UUID id) {
        return appointments.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));
    }
}
