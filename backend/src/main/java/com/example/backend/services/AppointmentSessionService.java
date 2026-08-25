package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.entities.ActivityAction;
import com.example.backend.security.CurrentUser;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.exception.SlotTakenException;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.Comparator;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

// Owns one treatment slot.
@Service
@RequiredArgsConstructor
public class AppointmentSessionService {

    private final AppointmentSessionRepository sessions;
    private final AppointmentRepository appointments;
    private final DoctorProfileRepository doctors;
    private final PatientProfileRepository patients;
    private final DoctorAvailabilityService availability;
    private final ClinicProperties clinic;
    private final ActivityLogService activityLogs;
    private final ActivityCorrelation correlation;
    private final CurrentUser currentUser;
    private final CancellationPolicy cancellation;
    private final Clock clock;

    @CacheEvict(value = "dashboardAnalytics", allEntries = true)
    @Transactional
    public AppointmentSessionResponse add(UUID appointmentId, AddSessionRequest request) {
        correlation.begin();

        try {
            return addToVisit(appointmentId, request);
        } finally {
            correlation.end();
        }
    }

    private AppointmentSessionResponse addToVisit(UUID appointmentId, AddSessionRequest request) {
        // Appointment, then patient, then session.
        Appointment appointment = appointments.findWithLockById(appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));

        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }

        // Judged on the treatment added, not visit.
        cancellation.assertEditable(request.startTime());

        // Taken once; patient overlap lacks a constraint.
        patients.lockForBooking(appointment.getPatient().getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));

        // A treatment joins the visit's own day.
        LocalDate visitDay = appointment.getScheduledAt().atZone(clinic.zone()).toLocalDate();
        LocalDate addedDay = request.startTime().atZone(clinic.zone()).toLocalDate();

        if (!addedDay.equals(visitDay)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That treatment is not on the day of this visit");
        }

        AppointmentSession added = schedule(appointment, request);

        // The visit changed, so name it.
        activityLogs.recordAppointment(
                currentUser.id().orElse(null),
                appointment.getPatient().getUserId(),
                ActivityAction.APPOINTMENT_SESSIONS_ADDED,
                appointment.getId());

        return AppointmentSessionResponse.of(added);
    }

    // Priced and timed at today's tariff.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request) {
        return schedule(appointment, request, clinic.tariffFor(request.treatmentName()));
    }

    // A held cancellation window cannot close silently.
    private void assertKeepsCancellationWindow(Appointment appointment, Instant addedStart) {
        if (!addedStart.isBefore(appointment.getScheduledAt())) {
            return;
        }

        if (cancellation.patientWindowOpen(appointment.getScheduledAt())
                && !cancellation.patientWindowOpen(addedStart)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "That treatment would start the visit inside the patient's cancellation window");
        }
    }

    // Only way a session exists.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request, Tariff tariff) {
        // Locked: turnover has no constraint.
        DoctorProfile practitioner = doctors.lockForBooking(request.practitionerUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        TreatmentName treatment = request.treatmentName();

        Instant startTime = request.startTime();
        Instant endTime = startTime.plus(Duration.ofMinutes(tariff.durationMinutes()));

        // Before the rest; add() checked first.
        assertKeepsCancellationWindow(appointment, startTime);
        assertNotAlreadyInVisit(appointment, treatment);
        assertQualified(practitioner, treatment);

        // One place names the failing pick.
        try {
            assertBookableWindow(startTime);
            cancellation.assertLeavesRoomToCancel(startTime);
            assertWithinWorkingHours(practitioner.getUserId(), startTime, endTime);
            assertFree(practitioner.getUserId(), startTime, endTime);
            assertPatientFree(appointment, startTime, endTime);
        } catch (SlotTakenException lost) {
            throw lost.forSlot(treatment.name(), practitioner.getUserId(), startTime);
        }

        AppointmentSession saved = sessions.save(new AppointmentSession(
                appointment, practitioner, treatment.category(), treatment,
                tariff.price(), tariff.durationMinutes(), startTime, endTime
        ));

        // Written now so races fail nameably.
        try {
            sessions.flush();
        } catch (DataIntegrityViolationException race) {
            RuntimeException mapped = slotTakenOrRethrow(race);

            if (mapped instanceof SlotTakenException lost) {
                throw lost.forSlot(treatment.name(), practitioner.getUserId(), startTime);
            }
            throw mapped;
        }

        activityLogs.recordSession(
                currentUser.id().orElse(null),
                appointment.getPatient().getUserId(),
                ActivityAction.SESSION_SCHEDULED,
                saved.getId());

        resyncScheduledAt(appointment, startTime);

        return saved;
    }

    // Only overlap constraints mean a lost slot.
    private RuntimeException slotTakenOrRethrow(DataIntegrityViolationException race) {
        Throwable cause = race.getMostSpecificCause();
        String message = cause.getMessage() == null ? "" : cause.getMessage();

        if (message.contains("session_no_practitioner_overlap")) {
            return new SlotTakenException("That time has just been taken. Please choose another one.");
        }

        if (message.contains("session_no_patient_overlap")) {
            return new SlotTakenException("You already have another treatment booked at that time.");
        }

        return race;
    }

    // Visit begins at its earliest live treatment.
    private void resyncScheduledAt(Appointment appointment, Instant candidate) {
        Instant earliest = liveStartTimes(appointment.getId())
                .min(Comparator.naturalOrder())
                .orElse(candidate);

        if (candidate.isBefore(earliest)) {
            appointment.setScheduledAt(candidate);
        } else {
            appointment.setScheduledAt(earliest);
        }
    }

    // The last cancellation leaves no visit.
    private void closeOrResyncAfterCancel(Appointment appointment) {
        Optional<Instant> earliest = liveStartTimes(appointment.getId()).min(Comparator.naturalOrder());

        if (earliest.isPresent()) {
            appointment.setScheduledAt(earliest.get());
            return;
        }

        if (appointment.getStatus() == AppointmentStatus.BOOKED) {
            appointment.cancel();

            // Visit ended, so log both levels.
            activityLogs.recordAppointment(
                    currentUser.id().orElse(null),
                    appointment.getPatient().getUserId(),
                    ActivityAction.APPOINTMENT_CANCELLED,
                    appointment.getId());
        }
    }

    private Stream<Instant> liveStartTimes(UUID appointmentId) {
        return sessions.findByAppointmentId(appointmentId).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .map(AppointmentSession::getStartTime);
    }

    // Drops one treatment; same cutoff applies.
    @CacheEvict(value = "dashboardAnalytics", allEntries = true)
    @Transactional
    public AppointmentSessionResponse cancel(UUID appointmentId, UUID sessionId) {
        correlation.begin();

        try {
            // Before the row; cancelling decides state.
            Appointment appointment = lockVisit(appointmentId);

            cancellation.assertCancellable(appointment.getScheduledAt());

            AppointmentSession session = require(appointmentId, sessionId);

            return transition(session, SessionStatus.CANCELLED);
        } finally {
            correlation.end();
        }
    }

    // Only place a whole visit cancels treatments.
    @Transactional
    public void cancelEveryPlannedIn(Appointment appointment) {
        sessions.findByAppointmentId(appointment.getId()).stream()
                .filter(s -> s.getStatus() == SessionStatus.PLANNED)
                .forEach(this::markCancelled);
    }

    private void markCancelled(AppointmentSession session) {
        session.setStatus(SessionStatus.CANCELLED);

        // Per treatment, so both routes match.
        activityLogs.recordSession(
                currentUser.id().orElse(null),
                session.getAppointment().getPatient().getUserId(),
                ActivityAction.SESSION_CANCELLED,
                session.getId());
    }

    // Lower cutoff only; visit locked first.
    @CacheEvict(value = "dashboardAnalytics", allEntries = true)
    @Transactional
    public AppointmentSessionResponse markAttended(UUID appointmentId, UUID sessionId) {
        lockVisit(appointmentId);

        AppointmentSession session = require(appointmentId, sessionId);
        assertAssignedDoctor(session);
        assertStarted(session);

        return transition(session, SessionStatus.COMPLETED);
    }

    @CacheEvict(value = "dashboardAnalytics", allEntries = true)
    @Transactional
    public AppointmentSessionResponse markNoShow(UUID appointmentId, UUID sessionId) {
        lockVisit(appointmentId);

        AppointmentSession session = require(appointmentId, sessionId);
        assertStarted(session);

        return transition(session, SessionStatus.NO_SHOW);
    }

    // Taken first, so writers queue.
    private Appointment lockVisit(UUID appointmentId) {
        return appointments.findWithLockById(appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));
    }

    // Marked early, COMPLETED blocks cancelling.
    private void assertStarted(AppointmentSession session) {
        if (session.getStartTime().isAfter(clock.instant())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That treatment has not started yet");
        }
    }

    private void assertAssignedDoctor(AppointmentSession session) {
        if (currentUser.hasRole(com.example.backend.security.Role.DOCTOR)
                && !session.getPractitioner().getUserId().equals(currentUser.requireId())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Doctors may only update their assigned sessions");
        }
    }

    // Scoped to the path, and locked.
    private AppointmentSession require(UUID appointmentId, UUID sessionId) {
        return sessions.findWithLockByIdAndAppointmentId(sessionId, appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session"));
    }

    private AppointmentSessionResponse transition(AppointmentSession session, SessionStatus to) {
        if (session.getStatus() != SessionStatus.PLANNED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Session is not planned");
        }

        if (to == SessionStatus.CANCELLED) {
            markCancelled(session);
            closeOrResyncAfterCancel(session.getAppointment());

            return AppointmentSessionResponse.of(session);
        }

        session.setStatus(to);

        activityLogs.recordSession(
                currentUser.id().orElse(null),
                session.getAppointment().getPatient().getUserId(),
                actionFor(to),
                session.getId());

        return AppointmentSessionResponse.of(session);
    }

    // The log names the status reached.
    private static ActivityAction actionFor(SessionStatus status) {
        return switch (status) {
            case CANCELLED -> ActivityAction.SESSION_CANCELLED;
            case COMPLETED -> ActivityAction.SESSION_COMPLETED;
            case NO_SHOW -> ActivityAction.SESSION_NO_SHOW;
            case PLANNED -> ActivityAction.SESSION_SCHEDULED;
        };
    }

    // Enforced here; schema never reads specializations.
    private void assertQualified(DoctorProfile practitioner, TreatmentName treatment) {
        if (treatment.category().qualifies(practitioner.getSpecializations())) {
            return;
        }

        throw new ResponseStatusException(
                HttpStatus.CONFLICT,
                "That doctor is not qualified for " + treatment
                        + "; it needs one of " + treatment.category().qualifying());
    }

    // Open for a season, not forever.
    private void assertBookableWindow(Instant startTime) {
        // Offered then gone: lost, not malformed.
        Instant now = clock.instant();
        if (startTime.isBefore(now)) {
            throw new SlotTakenException("That time has already passed");
        }

        if (startTime.isAfter(now.plus(clinic.horizon()))) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Bookings open only " + clinic.maxHorizonDays() + " days ahead");
        }
    }

    // Also reached by POST /sessions; cancelled excluded.
    private void assertNotAlreadyInVisit(Appointment appointment, TreatmentName treatment) {
        boolean already = sessions.findByAppointmentId(appointment.getId()).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .anyMatch(s -> s.getTreatmentName() == treatment);

        if (already) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That treatment is already in this visit");
        }
    }

    // Mirrors the overlap rule, widened by turnover.
    private void assertFree(UUID practitionerUserId, Instant startTime, Instant endTime) {
        Duration turnover = clinic.turnover();

        if (sessions.existsOverlappingActiveSession(
                practitionerUserId, startTime.minus(turnover), endTime.plus(turnover))) {
            throw new SlotTakenException("That time has just been taken. Please choose another one.");
        }
    }

    // Named here; the constraint holds races.
    private void assertPatientFree(Appointment appointment, Instant startTime, Instant endTime) {
        UUID patientUserId = appointment.getPatient().getUserId();

        if (sessions.existsOverlappingActiveSessionForPatient(patientUserId, startTime, endTime)) {
            throw new SlotTakenException("You already have another treatment booked at that time.");
        }
    }

    // Clinic wall clock. Binds every caller alike.
    private void assertWithinWorkingHours(UUID practitionerUserId, Instant startTime, Instant endTime) {
        ZonedDateTime start = startTime.atZone(clinic.zone());
        ZonedDateTime end = endTime.atZone(clinic.zone());

        // Spanning midnight never fits one window.
        boolean fits = start.toLocalDate().equals(end.toLocalDate())
                && availability.isOpenFor(
                        practitionerUserId, start.toLocalDate(), start.toLocalTime(), end.toLocalTime());

        if (!fits) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Outside the doctor's working hours");
        }
    }
}
