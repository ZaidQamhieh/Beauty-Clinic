package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.entities.ActivityAction;
import com.example.backend.security.CurrentUser;
import com.example.backend.security.Role;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentSessionResponse;
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
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.util.Comparator;
import java.util.List;
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

    @Transactional(readOnly = true)
    public List<AppointmentSessionResponse> list(UUID appointmentId) {
        return sessions.findByAppointmentId(appointmentId).stream()
                .map(AppointmentSessionResponse::of)
                .toList();
    }

    @Transactional
    public AppointmentSessionResponse add(UUID appointmentId, AddSessionRequest request) {
        Appointment appointment = appointments.findById(appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));

        if (appointment.getStatus() != AppointmentStatus.BOOKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Appointment is not booked");
        }

        return AppointmentSessionResponse.of(schedule(appointment, request));
    }

    // Priced at today's tariff, and its own length unless the caller may ask for longer.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request) {
        Tariff standard = clinic.tariffFor(request.treatmentName());

        int minutes = standard.durationMinutes();
        if (request.durationMinutes() != null) {
            minutes = request.durationMinutes();
        }

        assertMayRunFor(minutes);

        return schedule(appointment, request, new Tariff(standard.price(), minutes));
    }

    // Past the standard maximum the chair is blocked long enough that it is a clinical call.
    private void assertMayRunFor(int minutes) {
        if (minutes <= clinic.standardSessionMaxMinutes()) {
            return;
        }

        if (!currentUser.hasRole(Role.DOCTOR) && !currentUser.hasRole(Role.ADMIN)) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Sessions longer than " + clinic.standardSessionMaxMinutes()
                            + " minutes can only be booked by a doctor or an admin");
        }
    }

    // Only way a session exists, so no path skips a guard. The passed tariff never re-prices.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request, Tariff tariff) {
        DoctorProfile practitioner = doctors.findById(request.practitionerUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        TreatmentName treatment = request.treatmentName();

        Instant startTime = request.startTime();
        Instant endTime = startTime.plus(Duration.ofMinutes(tariff.durationMinutes()));

        assertQualified(practitioner, treatment);
        assertWithinWorkingHours(practitioner.getUserId(), startTime, endTime);
        assertFree(practitioner.getUserId(), startTime, endTime);
        assertPatientFree(appointment, startTime, endTime);

        AppointmentSession saved = sessions.save(new AppointmentSession(
                appointment, practitioner, treatment.category(), treatment,
                tariff.price(), tariff.durationMinutes(), startTime, endTime
        ));

        resyncScheduledAt(appointment, startTime);

        return saved;
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

    // A cancellation may push the start later; with no live session left, the time stands.
    private void resyncScheduledAtAfterCancel(Appointment appointment) {
        liveStartTimes(appointment.getId())
                .min(Comparator.naturalOrder())
                .ifPresent(appointment::setScheduledAt);
    }

    private Stream<Instant> liveStartTimes(UUID appointmentId) {
        return sessions.findByAppointmentId(appointmentId).stream()
                .filter(s -> s.getStatus() != SessionStatus.CANCELLED)
                .map(AppointmentSession::getStartTime);
    }

    @Transactional
    public AppointmentSessionResponse cancel(UUID appointmentId, UUID sessionId) {
        return transition(appointmentId, sessionId, SessionStatus.CANCELLED);
    }

    @Transactional
    public AppointmentSessionResponse markAttended(UUID appointmentId, UUID sessionId) {
        return transition(appointmentId, sessionId, SessionStatus.COMPLETED);
    }

    @Transactional
    public AppointmentSessionResponse markNoShow(UUID appointmentId, UUID sessionId) {
        return transition(appointmentId, sessionId, SessionStatus.NO_SHOW);
    }

    // Scoped to the appointment in the path, so a wrong id cannot hit another visit.
    private AppointmentSessionResponse transition(UUID appointmentId, UUID sessionId, SessionStatus to) {
        AppointmentSession session = sessions.findByIdAndAppointmentId(sessionId, appointmentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such session"));

        if (session.getStatus() != SessionStatus.PLANNED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Session is not planned");
        }

        session.setStatus(to);

        if (to == SessionStatus.CANCELLED) {
            resyncScheduledAtAfterCancel(session.getAppointment());
        }

        activityLogs.recordSession(
                currentUser.id().orElse(null),
                session.getAppointment().getPatient().getUserId(),
                ActivityAction.SESSION_STATUS_CHANGED,
                session.getId());

        return AppointmentSessionResponse.of(session);
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

    // Mirrors session_no_practitioner_overlap. Checked here so caller gets 409, not 500.
    private void assertFree(UUID practitionerUserId, Instant startTime, Instant endTime) {
        if (sessions.existsOverlappingActiveSession(practitionerUserId, startTime, endTime)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor already has a booking then");
        }
    }

    // Spans every visit, which session_no_patient_overlap does not; without the lock, a race.
    private void assertPatientFree(Appointment appointment, Instant startTime, Instant endTime) {
        UUID patientUserId = appointment.getPatient().getUserId();

        patients.lockForBooking(patientUserId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such patient"));

        if (sessions.existsOverlappingActiveSessionForPatient(patientUserId, startTime, endTime)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT, "The patient already has a treatment booked then");
        }
    }

    // Working hours are clinic wall clock, so resolve in clinic zone.
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
