package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;

// Owns one treatment slot. Creating it, and rules deciding it may exist.
@Service
@RequiredArgsConstructor
public class AppointmentSessionService {

    private final AppointmentSessionRepository sessions;
    private final AppointmentRepository appointments;
    private final DoctorProfileRepository doctors;
    private final DoctorAvailabilityService availability;
    private final ClinicProperties clinic;

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

    // Only way a session exists. Both guards here, so no path skips them.
    @Transactional
    public AppointmentSession schedule(Appointment appointment, AddSessionRequest request) {
        DoctorProfile practitioner = doctors.findById(request.practitionerUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such doctor"));

        Instant startTime = request.startTime();
        Instant endTime = startTime.plus(Duration.ofMinutes(request.durationMinutes()));

        assertWithinWorkingHours(practitioner.getUserId(), startTime, endTime);
        assertFree(practitioner.getUserId(), startTime, endTime);

        return sessions.save(new AppointmentSession(
                appointment, practitioner, request.category(), request.treatmentName(),
                request.priceCharged(), request.durationMinutes(), startTime, endTime
        ));
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
        return AppointmentSessionResponse.of(session);
    }

    // Mirrors session_no_practitioner_overlap. Checked here so caller gets 409, not 500.
    private void assertFree(UUID practitionerUserId, Instant startTime, Instant endTime) {
        if (sessions.existsOverlappingActiveSession(practitionerUserId, startTime, endTime)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Doctor already has a booking then");
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
