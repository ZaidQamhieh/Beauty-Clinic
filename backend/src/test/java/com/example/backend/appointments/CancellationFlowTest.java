package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.Appointment.AppointmentStatus;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.ActivityLogRepository;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.AccessTokenService;
import com.example.backend.services.AppointmentService;
import com.example.backend.services.AppointmentSessionService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

// The finalized cancellation flow, end to end against the real schema: one cutoff, then either
// the whole visit or one treatment, with the time released exactly where a status went CANCELLED.
@SpringBootTest
@ActiveProfiles("test")
class CancellationFlowTest extends AbstractIntegrationTest {

    @Autowired
    private AppointmentService appointmentService;

    @Autowired
    private AppointmentSessionService sessionService;

    @Autowired
    private TransactionTemplate transactions;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private AppointmentSessionRepository sessions;

    @Autowired
    private ActivityLogRepository activityLogs;

    @AfterEach
    void clearCaller() {
        SecurityContextHolder.clearContext();
    }

    // ─── Whole visit ────────────────────────────────────────────────────────

    @Test
    void cancellingVisitReleasesRemainingTreatments() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(start, planned(start), planned(start.plus(2, ChronoUnit.HOURS)));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        appointmentService.cancel(fixture.appointmentId());

        assertThat(sessionsOf(fixture)).allMatch(s -> s.getStatus() == SessionStatus.CANCELLED);
        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.CANCELLED);
        assertThat(sessionsOf(fixture)).allMatch(s -> timeIsFree(fixture, s));
    }

    // A finished treatment no longer holds anything cancellable, and must not block the rest.
    @Test
    void cancellingVisitKeepsFinishedWork() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(
                start,
                completed(hoursFromNow(-2)),
                planned(start));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        appointmentService.cancel(fixture.appointmentId());

        AppointmentSession finished = sessionOf(fixture, 0);
        AppointmentSession dropped = sessionOf(fixture, 1);

        assertThat(finished.getStatus()).isEqualTo(SessionStatus.COMPLETED);
        assertThat(dropped.getStatus()).isEqualTo(SessionStatus.CANCELLED);
        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.CANCELLED);

        // The finished treatment keeps its slot; only the cancelled one gives its time back.
        assertThat(timeIsFree(fixture, finished)).isFalse();
        assertThat(timeIsFree(fixture, dropped)).isTrue();
    }

    @Test
    void cannotCancelVisitTwice() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(start, planned(start));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        appointmentService.cancel(fixture.appointmentId());
        Instant cancelledAt = visitOf(fixture).getCancelledAt();

        assertThatThrownBy(() -> appointmentService.cancel(fixture.appointmentId()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("not booked");

        assertThat(visitOf(fixture).getCancelledAt()).isEqualTo(cancelledAt);
    }

    // ─── One treatment ──────────────────────────────────────────────────────

    @Test
    void cancellingTreatmentKeepsRestOfVisit() {
        Instant start = hoursFromNow(3);
        Instant later = start.plus(2, ChronoUnit.HOURS);
        Fixture fixture = visit(start, planned(start), planned(later));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        sessionService.cancel(fixture.appointmentId(), fixture.sessionIds().get(0));

        assertThat(sessionOf(fixture, 0).getStatus()).isEqualTo(SessionStatus.CANCELLED);
        assertThat(sessionOf(fixture, 1).getStatus()).isEqualTo(SessionStatus.PLANNED);

        Appointment visit = visitOf(fixture);
        assertThat(visit.getStatus()).isEqualTo(AppointmentStatus.BOOKED);
        // The visit now begins with what is left of it.
        assertThat(visit.getScheduledAt()).isEqualTo(later);

        assertThat(timeIsFree(fixture, sessionOf(fixture, 0))).isTrue();
        assertThat(timeIsFree(fixture, sessionOf(fixture, 1))).isFalse();
    }

    @Test
    void cancellingLastTreatmentCancelsVisit() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(start, planned(start));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        sessionService.cancel(fixture.appointmentId(), fixture.sessionIds().get(0));

        assertThat(sessionOf(fixture, 0).getStatus()).isEqualTo(SessionStatus.CANCELLED);
        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.CANCELLED);
        assertThat(timeIsFree(fixture, sessionOf(fixture, 0))).isTrue();
    }

    @Test
    void cannotCancelTreatmentTwice() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(start, planned(start), planned(start.plus(2, ChronoUnit.HOURS)));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        UUID sessionId = fixture.sessionIds().get(0);
        sessionService.cancel(fixture.appointmentId(), sessionId);

        assertThatThrownBy(() -> sessionService.cancel(fixture.appointmentId(), sessionId))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("not planned");
    }

    // ─── The cutoff ─────────────────────────────────────────────────────────

    @Test
    void refusalInsideCutoffChangesNothing() {
        Instant start = Instant.now().plus(30, ChronoUnit.MINUTES);
        Fixture fixture = visit(start, planned(start));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        assertThatThrownBy(() -> appointmentService.cancel(fixture.appointmentId()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("60 minutes before");

        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.BOOKED);
        assertThat(visitOf(fixture).getCancelledAt()).isNull();
        assertThat(sessionOf(fixture, 0).getStatus()).isEqualTo(SessionStatus.PLANNED);
        assertThat(timeIsFree(fixture, sessionOf(fixture, 0))).isFalse();
        assertThat(cancellationLogsFor(fixture)).isEmpty();
    }

    // The cutoff is the visit's, not the treatment's: a late visit closes its later treatments too.
    @Test
    void treatmentFollowsVisitCutoff() {
        Instant start = Instant.now().plus(30, ChronoUnit.MINUTES);
        Instant later = start.plus(5, ChronoUnit.HOURS);
        Fixture fixture = visit(start, planned(start), planned(later));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        assertThatThrownBy(() -> sessionService.cancel(fixture.appointmentId(), fixture.sessionIds().get(1)))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("60 minutes before");

        assertThat(sessionOf(fixture, 1).getStatus()).isEqualTo(SessionStatus.PLANNED);
        assertThat(cancellationLogsFor(fixture)).isEmpty();
    }

    @Test
    void staffCanCancelInsidePatientCutoff() {
        Instant start = Instant.now().plus(30, ChronoUnit.MINUTES);
        Fixture fixture = visit(start, planned(start));
        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);

        appointmentService.cancel(fixture.appointmentId());

        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.CANCELLED);
        assertThat(sessionOf(fixture, 0).getStatus()).isEqualTo(SessionStatus.CANCELLED);
    }

    @Test
    void staffCannotCancelStartedVisit() {
        Instant start = Instant.now().minus(5, ChronoUnit.MINUTES);
        Fixture fixture = visit(start, planned(start));
        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);

        assertThatThrownBy(() -> appointmentService.cancel(fixture.appointmentId()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("already started");

        assertThat(visitOf(fixture).getStatus()).isEqualTo(AppointmentStatus.BOOKED);
        assertThat(sessionOf(fixture, 0).getStatus()).isEqualTo(SessionStatus.PLANNED);
    }

    // ─── Logging ────────────────────────────────────────────────────────────

    @Test
    void logsEachTreatmentAndVisit() {
        Instant start = hoursFromNow(3);
        Fixture fixture = visit(start, planned(start), planned(start.plus(2, ChronoUnit.HOURS)));
        callerIs(fixture.patientUserId(), Role.PATIENT);

        appointmentService.cancel(fixture.appointmentId());

        assertThat(cancellationLogsFor(fixture))
                .filteredOn(log -> log.getAction() == ActivityAction.SESSION_CANCELLED)
                .hasSize(2);
        assertThat(cancellationLogsFor(fixture))
                .filteredOn(log -> log.getAction() == ActivityAction.APPOINTMENT_CANCELLED)
                .hasSize(1);
    }

    // ─── Fixtures ───────────────────────────────────────────────────────────

    private record Fixture(
            UUID patientUserId,
            UUID doctorUserId,
            UUID appointmentId,
            List<UUID> sessionIds
    ) {
    }

    private record Planned(Instant start, SessionStatus status) {
    }

    private Planned planned(Instant start) {
        return new Planned(start, SessionStatus.PLANNED);
    }

    private Planned completed(Instant start) {
        return new Planned(start, SessionStatus.COMPLETED);
    }

    // Rows written directly: the booking rules are not what is under test here.
    private Fixture visit(Instant scheduledAt, Planned... planned) {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount doctorAccount = users.save(new UserAccount(
                    "doctor-" + unique + "@example.com", "hash", "Dee", "Oakes", Role.DOCTOR));
            DoctorProfile doctor = doctors.save(new DoctorProfile(doctorAccount));

            UserAccount patientAccount = users.save(new UserAccount(
                    "patient-" + unique + "@example.com", "hash", "Pat", "Ient", Role.PATIENT));
            PatientProfile patient = new PatientProfile(patientAccount);
            patient.setSkinType(SkinType.NORMAL);
            patients.save(patient);

            Appointment appointment = appointments.save(new Appointment(patient, scheduledAt));

            List<UUID> sessionIds = java.util.Arrays.stream(planned)
                    .map(one -> {
                        AppointmentSession session = sessions.save(
                                session(appointment, doctor, one.start()));
                        session.setStatus(one.status());
                        return sessions.save(session).getId();
                    })
                    .toList();

            return new Fixture(
                    patient.getUserId(), doctor.getUserId(), appointment.getId(), sessionIds);
        });
    }

    private AppointmentSession session(Appointment appointment, DoctorProfile doctor, Instant start) {
        return new AppointmentSession(
                appointment,
                doctor,
                TreatmentName.CONSULTATION.category(),
                TreatmentName.CONSULTATION,
                new BigDecimal("100.00"),
                30,
                start,
                start.plus(30, ChronoUnit.MINUTES));
    }

    private void callerIs(UUID userId, Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, userId.toString())
                .build();

        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(token, List.of(role.authority())));
    }

    private Instant hoursFromNow(int hours) {
        return Instant.now().plus(hours, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
    }

    private Appointment visitOf(Fixture fixture) {
        return appointments.findById(fixture.appointmentId()).orElseThrow();
    }

    private List<AppointmentSession> sessionsOf(Fixture fixture) {
        return sessions.findByAppointmentId(fixture.appointmentId());
    }

    private AppointmentSession sessionOf(Fixture fixture, int index) {
        return sessions.findById(fixture.sessionIds().get(index)).orElseThrow();
    }

    // What the schedule sees: a released time is one no live session overlaps any more.
    private boolean timeIsFree(Fixture fixture, AppointmentSession session) {
        return !sessions.existsOverlappingActiveSession(
                fixture.doctorUserId(), session.getStartTime(), session.getEndTime());
    }

    private List<ActivityLog> cancellationLogsFor(Fixture fixture) {
        List<UUID> ofVisit = new java.util.ArrayList<>(fixture.sessionIds());
        ofVisit.add(fixture.appointmentId());

        return activityLogs.findAll().stream()
                .filter(log -> ofVisit.contains(log.getEntityId()))
                .filter(log -> log.getAction() == ActivityAction.SESSION_CANCELLED
                        || log.getAction() == ActivityAction.APPOINTMENT_CANCELLED)
                .toList();
    }
}
