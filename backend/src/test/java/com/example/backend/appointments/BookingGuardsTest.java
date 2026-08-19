package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.BookAppointmentRequest;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorAvailabilityRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.example.backend.services.AccessTokenService;
import com.example.backend.services.AppointmentService;
import com.example.backend.services.AppointmentSessionService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

// The guards around booking that the cancellation cutoff implies: a patient may not book what
// they could not cancel, and nobody may move a visit's start inside a window the patient holds.
@SpringBootTest
@ActiveProfiles("test")
class BookingGuardsTest extends AbstractIntegrationTest {

    // The clinic zone is pinned to UTC for tests, so a wall-clock day is a UTC day.
    private static final LocalDate DAY = LocalDate.now(ZoneOffset.UTC).plusDays(2);

    @MockitoBean
    private Clock clock;

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
    private DoctorAvailabilityRepository availabilities;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private AppointmentSessionRepository sessions;

    @BeforeEach
    void realTimeByDefault() {
        when(clock.instant()).thenAnswer(invocation -> Instant.now());
    }

    @AfterEach
    void clearCaller() {
        SecurityContextHolder.clearContext();
    }

    // ─── R1: a patient may not book inside their own cancellation window ────

    @Test
    void patientCannotBookInsideCutoff() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);

        Instant soon = Instant.now().plus(30, ChronoUnit.MINUTES);

        assertThatThrownBy(() -> appointmentService.book(booking(fixture, soon)))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("at least 60 minutes ahead");

        assertThat(appointments.findByPatientUserId(fixture.patientUserId())).isEmpty();
    }

    @Test
    void patientCanBookBeyondCutoff() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);

        assertThatCode(() -> appointmentService.book(booking(fixture, at(10, 0))))
                .doesNotThrowAnyException();

        assertThat(appointments.findByPatientUserId(fixture.patientUserId())).hasSize(1);
    }

    // ─── R2: adding earlier work may not close a window the patient holds ───

    @Test
    void rejectsTreatmentInsideWindow() {
        Fixture fixture = clinic();
        Instant visitStart = at(13, 30);
        UUID appointmentId = visitWith(fixture, planned(visitStart));

        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);
        // Half an hour before the added treatment: the patient could still cancel at 13:30,
        // and could not at 12:00.
        nowIs(at(11, 30));

        assertThatThrownBy(() -> sessionService.add(appointmentId, session(fixture, at(12, 0))))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("cancellation window");

        assertThat(sessions.findByAppointmentId(appointmentId)).hasSize(1);
        assertThat(appointments.findById(appointmentId).orElseThrow().getScheduledAt())
                .isEqualTo(visitStart);
    }

    @Test
    void allowsEarlierTreatmentWhileWindowOpen() {
        Fixture fixture = clinic();
        Instant visitStart = at(13, 30);
        // Not a consultation: the added session is one, and a visit holds each once.
        UUID appointmentId = visitWith(fixture, planned(visitStart, TreatmentName.MICRONEEDLING));

        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);
        nowIs(at(11, 30));

        sessionService.add(appointmentId, session(fixture, at(13, 0)));

        assertThat(sessions.findByAppointmentId(appointmentId)).hasSize(2);
        // The visit legitimately starts earlier now, and the patient can still cancel it.
        assertThat(appointments.findById(appointmentId).orElseThrow().getScheduledAt())
                .isEqualTo(at(13, 0));
    }

    // ─── T2: only work still to come is released while rescheduling ─────────

    @Test
    void releasesOnlyPlannedTreatments() {
        Fixture fixture = clinic();
        UUID appointmentId = visitWith(
                fixture,
                new Slot(at(10, 0), SessionStatus.COMPLETED, TreatmentName.CONSULTATION),
                new Slot(at(14, 0), SessionStatus.PLANNED, TreatmentName.MICRONEEDLING));

        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);

        List<FreeSlotResponse> free = appointmentService.freeSlots(new FreeSlotQuery(
                TreatmentName.CONSULTATION, DAY, fixture.doctorUserId(), null, List.of(), appointmentId));

        // The cancelled-to-be treatment gives its time back; work already carried out does not.
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(14, 0)));
        assertThat(free).noneMatch(slot -> slot.startTime().isBefore(at(10, 20))
                && slot.endTime().isAfter(at(10, 0)));
    }

    // ─── Fixtures ───────────────────────────────────────────────────────────

    private record Fixture(UUID patientUserId, UUID doctorUserId) {
    }

    private record Slot(Instant start, SessionStatus status, TreatmentName treatment) {
    }

    private Slot planned(Instant start) {
        return new Slot(start, SessionStatus.PLANNED, TreatmentName.CONSULTATION);
    }

    // A visit holds each treatment once, so a test that adds a second session
    // has to seed the first one as something else.
    private Slot planned(Instant start, TreatmentName treatment) {
        return new Slot(start, SessionStatus.PLANNED, treatment);
    }

    private void nowIs(Instant now) {
        when(clock.instant()).thenReturn(now);
    }

    private Instant at(int hour, int minute) {
        return DAY.atTime(LocalTime.of(hour, minute)).toInstant(ZoneOffset.UTC);
    }

    private Fixture clinic() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount doctorAccount = users.save(new UserAccount(
                    "doctor-" + unique + "@example.com", "hash", "Dee", "Oakes", Role.DOCTOR));
            DoctorProfile doctor = doctors.save(new DoctorProfile(doctorAccount));

            // Open all day, every day, so working hours are never what a test is measuring.
            availabilities.save(new DoctorAvailability(
                    doctor,
                    AvailabilityKind.OVERRIDE,
                    null,
                    LocalTime.of(0, 0),
                    LocalTime.of(23, 59),
                    DAY));

            UserAccount patientAccount = users.save(new UserAccount(
                    "patient-" + unique + "@example.com", "hash", "Pat", "Ient", Role.PATIENT));
            PatientProfile patient = new PatientProfile(patientAccount);
            patient.setSkinType(SkinType.NORMAL);
            patients.save(patient);

            return new Fixture(patient.getUserId(), doctor.getUserId());
        });
    }

    // Rows written directly, so a fixture can hold a state booking would not produce.
    private UUID visitWith(Fixture fixture, Slot... slots) {
        return transactions.execute(status -> {
            PatientProfile patient = patients.findById(fixture.patientUserId()).orElseThrow();
            DoctorProfile doctor = doctors.findById(fixture.doctorUserId()).orElseThrow();

            Appointment appointment = appointments.save(new Appointment(patient, slots[0].start()));

            for (Slot slot : slots) {
                AppointmentSession session = sessions.save(new AppointmentSession(
                        appointment,
                        doctor,
                        slot.treatment().category(),
                        slot.treatment(),
                        new BigDecimal("100.00"),
                        20,
                        slot.start(),
                        slot.start().plus(20, ChronoUnit.MINUTES)));
                session.setStatus(slot.status());
                sessions.save(session);
            }

            return appointment.getId();
        });
    }

    private BookAppointmentRequest booking(Fixture fixture, Instant start) {
        return new BookAppointmentRequest(
                fixture.patientUserId(), List.of(session(fixture, start)), null);
    }

    private AddSessionRequest session(Fixture fixture, Instant start) {
        return new AddSessionRequest(fixture.doctorUserId(), TreatmentName.CONSULTATION, start);
    }

    private void callerIs(UUID userId, Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, userId.toString())
                .build();

        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(token, List.of(role.authority())));
    }
}
