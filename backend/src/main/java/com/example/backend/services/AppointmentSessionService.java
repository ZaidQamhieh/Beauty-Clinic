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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.Comparator;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

// Owns one treatment slot. Creating it, and rules deciding it may exist.
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
    private final CurrentUser currentUser;

    @Transactional
    public AppointmentSessionResponse add(UUID appointmentId, AddSessionRequest request) {
        // Appointment, then patient, then session.
        Appointment appointment = appointments.findWithLockById(appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));

        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }

        // Taken once, as book() does: the patient-overlap check has no constraint behind it.
        patients.lockForBooking(appointment.getPatient().getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));

        // A later treatment joins the day the visit already has, or it drags the visit back.
        LocalDate visitDay = appointment.getScheduledAt().atZone(clinic.zone()).toLocalDate();
        LocalDate addedDay = request.startTime().atZone(clinic.zone()).toLocalDate();

        if (!addedDay.equals(visitDay)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That treatment is not on the day of this visit");
        }

        return AppointmentSessionResponse.of(schedule(appointment, request));
    }

    // Priced and timed at today's tariff. Nobody picks a length; the treatment carries one.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request) {
        return schedule(appointment, request, clinic.tariffFor(request.treatmentName()));
    }

    // A patient may change their visit until its day begins; the desk works the day itself.
    public void assertChangeable(Instant startTime) {
        Instant now = Instant.now();

        if (currentUser.isClinicStaff()) {
            if (!startTime.isAfter(now)) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT, "That appointment has already started");
            }
            return;
        }

        // Clinic midnight, not the caller's: the appointment's day is a wall-clock day.
        Instant dayBegins = startTime.atZone(clinic.zone())
                .toLocalDate()
                .atStartOfDay(clinic.zone())
                .toInstant();

        if (!now.isBefore(dayBegins)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Changes close at midnight before the day of the appointment");
        }
    }

    // The only way a session exists. Caller holds the patient lock; the tariff never re-prices.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request, Tariff tariff) {
        DoctorProfile practitioner = doctors.findById(request.practitionerUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        TreatmentName treatment = request.treatmentName();

        Instant startTime = request.startTime();
        Instant endTime = startTime.plus(Duration.ofMinutes(tariff.durationMinutes()));

        assertQualified(practitioner, treatment);
        assertBookableWindow(startTime);
        assertWithinWorkingHours(practitioner.getUserId(), startTime, endTime);
        assertFree(practitioner.getUserId(), startTime, endTime);
        assertPatientFree(appointment, startTime, endTime);

        AppointmentSession saved = sessions.save(new AppointmentSession(
                appointment, practitioner, treatment.category(), treatment,
                tariff.price(), tariff.durationMinutes(), startTime, endTime
        ));

        // Written now, not at commit, so a race that beat the checks fails where we can name it.
        try {
            sessions.flush();
        } catch (DataIntegrityViolationException race) {
            throw slotTakenOrRethrow(race);
        }

        activityLogs.recordSession(
                currentUser.id().orElse(null),
                appointment.getPatient().getUserId(),
                ActivityAction.SESSION_SCHEDULED,
                saved.getId());

        resyncScheduledAt(appointment, startTime);

        return saved;
    }

    // Only the overlap constraints mean a lost slot; every other violation keeps its own error.
    private RuntimeException slotTakenOrRethrow(DataIntegrityViolationException race) {
        Throwable cause = race.getMostSpecificCause();
        String message = cause.getMessage() == null ? "" : cause.getMessage();

        if (message.contains("session_no_practitioner_overlap")) {
            return new SlotTakenException("Doctor already has a booking then, or too close to one");
        }

        if (message.contains("session_no_patient_overlap")) {
            return new SlotTakenException("The patient already has a treatment booked then");
        }

        return race;
    }

    // The visit begins when its earliest live treatment does, or the day's schedule missorts.
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

    // A cancellation may push the start later; the last one leaves no visit to keep.
    private void closeOrResyncAfterCancel(Appointment appointment) {
        Optional<Instant> earliest = liveStartTimes(appointment.getId()).min(Comparator.naturalOrder());

        if (earliest.isPresent()) {
            appointment.setScheduledAt(earliest.get());
            return;
        }

        if (appointment.getStatus() == AppointmentStatus.BOOKED) {
            appointment.cancel();

            // The visit ended here, not just this treatment, so the log says so at both levels.
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

    // Dropping one treatment out of a visit. Bound by the same cutoff as dropping the visit.
    @Transactional
    public AppointmentSessionResponse cancel(UUID appointmentId, UUID sessionId) {
        // Before the session row: cancelling decides the visit's state.
        appointments.findWithLockById(appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));

        AppointmentSession session = require(appointmentId, sessionId);
        assertChangeable(session.getStartTime());

        return transition(session, SessionStatus.CANCELLED);
    }

    // No upper cutoff, only the lower one.
    @Transactional
    public AppointmentSessionResponse markAttended(UUID appointmentId, UUID sessionId) {
        AppointmentSession session = require(appointmentId, sessionId);
        assertStarted(session);

        return transition(session, SessionStatus.COMPLETED);
    }

    @Transactional
    public AppointmentSessionResponse markNoShow(UUID appointmentId, UUID sessionId) {
        AppointmentSession session = require(appointmentId, sessionId);
        assertStarted(session);

        return transition(session, SessionStatus.NO_SHOW);
    }

    // Marked early, COMPLETED blocks cancelling and NO_SHOW locks the slot.
    private void assertStarted(AppointmentSession session) {
        if (session.getStartTime().isAfter(Instant.now())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "That treatment has not started yet");
        }
    }

    // Scoped to the path's appointment, and locked: every caller changes this row's status.
    private AppointmentSession require(UUID appointmentId, UUID sessionId) {
        return sessions.findWithLockByIdAndAppointmentId(sessionId, appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session"));
    }

    private AppointmentSessionResponse transition(AppointmentSession session, SessionStatus to) {
        if (session.getStatus() != SessionStatus.PLANNED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Session is not planned");
        }

        session.setStatus(to);

        if (to == SessionStatus.CANCELLED) {
            closeOrResyncAfterCancel(session.getAppointment());
        }

        activityLogs.recordSession(
                currentUser.id().orElse(null),
                session.getAppointment().getPatient().getUserId(),
                actionFor(to),
                session.getId());

        return AppointmentSessionResponse.of(session);
    }

    // The log names the status reached, so reading it back does not need the row it describes.
    private static ActivityAction actionFor(SessionStatus status) {
        return switch (status) {
            case CANCELLED -> ActivityAction.SESSION_CANCELLED;
            case COMPLETED -> ActivityAction.SESSION_COMPLETED;
            case NO_SHOW -> ActivityAction.SESSION_NO_SHOW;
            case PLANNED -> ActivityAction.SESSION_SCHEDULED;
        };
    }

    // Enforced only here: the schema stores specializations and never reads them.
    private void assertQualified(DoctorProfile practitioner, TreatmentName treatment) {
        if (treatment.category().qualifies(practitioner.getSpecializations())) {
            return;
        }

        throw new ResponseStatusException(
                HttpStatus.CONFLICT,
                "That doctor is not qualified for " + treatment
                        + "; it needs one of " + treatment.category().qualifying());
    }

    // Open for a season, not forever. No notice period.
    private void assertBookableWindow(Instant startTime) {
        // The slot was offered, then went. That is a lost slot, not a malformed request.
        if (startTime.isBefore(Instant.now())) {
            throw new SlotTakenException("That time has already passed");
        }

        if (startTime.isAfter(Instant.now().plus(clinic.horizon()))) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Bookings open only " + clinic.maxHorizonDays() + " days ahead");
        }
    }

    // Mirrors session_no_practitioner_overlap, widened by turnover, which is a clinic rule.
    private void assertFree(UUID practitionerUserId, Instant startTime, Instant endTime) {
        Duration turnover = clinic.turnover();

        if (sessions.existsOverlappingActiveSession(
                practitionerUserId, startTime.minus(turnover), endTime.plus(turnover))) {
            throw new SlotTakenException("Doctor already has a booking then, or too close to one");
        }
    }

    // Spans every visit; session_no_patient_overlap is keyed on one, so the lock does the rest.
    private void assertPatientFree(Appointment appointment, Instant startTime, Instant endTime) {
        UUID patientUserId = appointment.getPatient().getUserId();

        if (sessions.existsOverlappingActiveSessionForPatient(patientUserId, startTime, endTime)) {
            throw new SlotTakenException("The patient already has a treatment booked then");
        }
    }

    // Clinic wall clock. Binds every caller alike.
    private void assertWithinWorkingHours(UUID practitionerUserId, Instant startTime, Instant endTime) {
        ZonedDateTime start = startTime.atZone(clinic.zone());
        ZonedDateTime end = endTime.atZone(clinic.zone());

        // Booking spanning midnight never fits: a window is bounded by one day.
        boolean fits = start.toLocalDate().equals(end.toLocalDate())
                && availability.isOpenFor(
                        practitionerUserId, start.toLocalDate(), start.toLocalTime(), end.toLocalTime());

        if (!fits) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Outside the doctor's working hours");
        }
    }
}
