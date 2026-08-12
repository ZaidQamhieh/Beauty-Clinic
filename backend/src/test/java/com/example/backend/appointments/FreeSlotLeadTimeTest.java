package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.FreeSlotQuery;
import com.example.backend.dtos.FreeSlotResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.SessionStatus;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorAvailability;
import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.DoctorProfile.Specialization;
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
import static org.mockito.Mockito.when;

// Slot search mirrors the patient lead-time rule.
@SpringBootTest
@ActiveProfiles("test")
class FreeSlotLeadTimeTest extends AbstractIntegrationTest {

    private static final LocalDate DAY = LocalDate.parse("2026-08-12");

    @MockitoBean
    private Clock clock;

    @Autowired
    private AppointmentService appointmentService;

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

    // ─── The cutoff boundary for a patient ────────────────────────────────────

    @Test
    void offersSlotAtCutoff() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        // now + cutoff = 11:00, on the grid.
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(11, 0)));
    }

    @Test
    void hidesSlotsInsideCutoff() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        // Nothing inside the cutoff may be advertised.
        assertThat(free).noneMatch(slot -> slot.startTime().isBefore(at(11, 0)));
    }

    @Test
    void offersSlotsBeyondCutoff() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(12, 0)));
    }

    @Test
    void findsSlotsAcrossEligibleDoctors() {
        Fixture fixture = clinic();
        UUID other = anotherDoctor();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> selected = free(fixture, TreatmentName.CONSULTATION);
        List<FreeSlotResponse> free = freeAcrossDoctors(fixture, TreatmentName.CONSULTATION);

        assertThat(free).containsAll(selected);
        // Naming one doctor excludes the other.
        assertThat(selected).noneMatch(slot -> slot.practitionerUserId().equals(other));
        assertThat(free).anyMatch(slot -> slot.practitionerUserId().equals(other));
    }

    // The boundary is exact to the second.
    @Test
    void appliesCutoffToTheSecond() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        // Cutoff lands at 11:00:30, so 11:00 is inside.
        nowIs(at(10, 0).plusSeconds(30));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        assertThat(free).noneMatch(slot -> slot.startTime().equals(at(11, 0)));
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(11, 15)));
    }

    // A clock that ticks between reads must not split the boundary.
    @Test
    void oneInstantDecidesTheWholeSearch() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);

        Instant first = at(10, 0);
        when(clock.instant()).thenReturn(first, first.plusMillis(1), first.plusMillis(2),
                first.plusSeconds(1), first.plusSeconds(2));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        // Captured now decides it, so 11:00 survives a later tick.
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(11, 0)));
    }

    // ─── Staff are exempt ─────────────────────────────────────────────────────

    @Test
    void offersShortNoticeSlotsToStaff() {
        Fixture fixture = clinic();
        callerIs(fixture.doctorUserId(), Role.RECEPTIONIST);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = free(fixture, TreatmentName.CONSULTATION);

        // Inside the patient window, but the desk books.
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(10, 15)));
    }

    // ─── Cutoff measured from the start ───────────────────────────────────────

    @Test
    void cutoffIgnoresDuration() {
        Fixture fixture = clinic();
        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        Instant shortest = earliest(free(fixture, TreatmentName.CONSULTATION));
        Instant longest = earliest(free(fixture, TreatmentName.LASER_RESURFACING));

        // Short and long treatments share one cutoff.
        assertThat(shortest).isEqualTo(at(11, 0));
        assertThat(longest).isEqualTo(at(11, 0));
    }

    // ─── Rescheduling still releases the replaced visit's future time ─────────

    @Test
    void rescheduleOffersReleasedSlot() {
        Fixture fixture = clinic();
        UUID replaced = visitWith(fixture, at(14, 0));

        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = appointmentService.freeSlots(new FreeSlotQuery(
                TreatmentName.CONSULTATION, DAY, fixture.doctorUserId(),
                fixture.patientUserId(), List.of(), replaced));

        // The released 14:00 returns, safely past cutoff.
        assertThat(free).anyMatch(slot -> slot.startTime().equals(at(14, 0)));
    }

    // Released time inside the cutoff stays withheld.
    @Test
    void rescheduleRespectsCutoff() {
        Fixture fixture = clinic();
        UUID replaced = visitWith(fixture, at(10, 30));

        callerIs(fixture.patientUserId(), Role.PATIENT);
        nowIs(at(10, 0));

        List<FreeSlotResponse> free = appointmentService.freeSlots(new FreeSlotQuery(
                TreatmentName.CONSULTATION, DAY, fixture.doctorUserId(),
                fixture.patientUserId(), List.of(), replaced));

        // Released, but still inside the patient cutoff.
        assertThat(free).noneMatch(slot -> slot.startTime().isBefore(at(11, 0)));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private List<FreeSlotResponse> free(Fixture fixture, TreatmentName treatment) {
        return appointmentService.freeSlots(new FreeSlotQuery(
                treatment, DAY, fixture.doctorUserId(), fixture.patientUserId(), List.of(), null));
    }

    // A second doctor, so search must fan out.
    private UUID anotherDoctor() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount account = users.save(new UserAccount(
                    "doctor2-" + unique + "@example.com", "hash", "Dana", "Reed", Role.DOCTOR));
            DoctorProfile doctor = new DoctorProfile(account);
            doctor.setSpecializations(List.of(Specialization.LASER_THERAPY));
            doctors.save(doctor);

            availabilities.save(new DoctorAvailability(
                    doctor,
                    AvailabilityKind.OVERRIDE,
                    null,
                    LocalTime.of(0, 0),
                    LocalTime.of(23, 59),
                    DAY));

            return doctor.getUserId();
        });
    }

    private List<FreeSlotResponse> freeAcrossDoctors(Fixture fixture, TreatmentName treatment) {
        return appointmentService.freeSlots(new FreeSlotQuery(
                treatment, DAY, null, fixture.patientUserId(), List.of(), null));
    }

    private Instant earliest(List<FreeSlotResponse> free) {
        return free.stream().map(FreeSlotResponse::startTime).min(java.util.Comparator.naturalOrder())
                .orElseThrow();
    }

    private record Fixture(UUID patientUserId, UUID doctorUserId) {
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
            DoctorProfile doctor = new DoctorProfile(doctorAccount);
            // Laser too, so duration can vary.
            doctor.setSpecializations(List.of(Specialization.LASER_THERAPY));
            doctors.save(doctor);

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

    // A planned session written directly for reschedule.
    private UUID visitWith(Fixture fixture, Instant start) {
        return transactions.execute(status -> {
            PatientProfile patient = patients.findById(fixture.patientUserId()).orElseThrow();
            DoctorProfile doctor = doctors.findById(fixture.doctorUserId()).orElseThrow();

            Appointment appointment = appointments.save(new Appointment(patient, start));
            AppointmentSession session = sessions.save(new AppointmentSession(
                    appointment,
                    doctor,
                    TreatmentName.CONSULTATION.category(),
                    TreatmentName.CONSULTATION,
                    new BigDecimal("100.00"),
                    20,
                    start,
                    start.plus(20, ChronoUnit.MINUTES)));
            session.setStatus(SessionStatus.PLANNED);
            sessions.save(session);

            return appointment.getId();
        });
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
