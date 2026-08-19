package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.AppointmentResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.PatientProfile.SkinType;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

// Upcoming and history partition the patient's visits.
@SpringBootTest
@ActiveProfiles("test")
class UpcomingHistoryTest extends AbstractIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-08-11T12:00:00Z");

    @MockitoBean
    private Clock clock;

    @Autowired
    private AppointmentService appointmentService;

    @Autowired
    private TransactionTemplate transactions;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private AppointmentRepository appointments;

    @BeforeEach
    void pinClock() {
        when(clock.instant()).thenReturn(NOW);
    }

    @AfterEach
    void clearCaller() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void returnsFutureBookings() {
        World world = world();
        callerIs(world.patientUserId(), Role.PATIENT);

        List<UUID> upcoming = ids(appointmentService.readOwnUpcoming(PageRequest.of(0, 20)));

        // Future booked and replacement, ascending.
        assertThat(upcoming).containsExactly(world.futureBooked(), world.replacement());
        assertThat(upcoming).doesNotContain(
                world.pastBooked(), world.futureCancelled(), world.superseded());
    }

    // A short page still counts the whole run.
    @Test
    void upcomingCountsBeyondThePage() {
        World world = world();
        callerIs(world.patientUserId(), Role.PATIENT);

        Page<AppointmentResponse> first = appointmentService.readOwnUpcoming(PageRequest.of(0, 1));

        assertThat(first.getContent()).hasSize(1);
        assertThat(ids(first)).containsExactly(world.futureBooked());
        assertThat(first.getTotalElements()).isEqualTo(2);
    }

    @Test
    void returnsPastAndCancelledBookings() {
        World world = world();
        callerIs(world.patientUserId(), Role.PATIENT);

        List<UUID> history = ids(appointmentService.readOwnHistory(PageRequest.of(0, 20)));

        // Cancelled future sorts ahead of the past visit.
        assertThat(history).containsExactly(world.futureCancelled(), world.pastBooked());
        assertThat(history).doesNotContain(
                world.futureBooked(), world.replacement(), world.superseded());
    }

    // A short page still counts the whole run.
    @Test
    void historyCountsBeyondThePage() {
        World world = world();
        callerIs(world.patientUserId(), Role.PATIENT);

        Page<AppointmentResponse> first = appointmentService.readOwnHistory(PageRequest.of(0, 1));

        assertThat(first.getContent()).hasSize(1);
        assertThat(ids(first)).containsExactly(world.futureCancelled());
        assertThat(first.getTotalElements()).isEqualTo(2);
    }

    // The derived count must match the unpaged run.
    @Test
    void nonSupersededCountsBeyondThePage() {
        World world = world();
        callerIs(world.patientUserId(), Role.PATIENT);

        Page<AppointmentResponse> first = appointmentService.readOwnAsPatient(PageRequest.of(0, 1));

        assertThat(first.getContent()).hasSize(1);
        assertThat(first.getTotalElements()).isEqualTo(4);
    }

    // Equal timestamps must not repeat or drop a row.
    @Test
    void pagesEqualTimestampsWithoutOverlap() {
        UUID patientUserId = twinsAt(NOW.plus(6, ChronoUnit.HOURS));
        callerIs(patientUserId, Role.PATIENT);

        List<UUID> firstPage = ids(appointmentService.readOwnUpcoming(PageRequest.of(0, 1)));
        List<UUID> secondPage = ids(appointmentService.readOwnUpcoming(PageRequest.of(1, 1)));

        assertThat(firstPage).hasSize(1);
        assertThat(secondPage).hasSize(1);
        assertThat(firstPage).doesNotContainAnyElementsOf(secondPage);
    }

    // ─── World ────────────────────────────────────────────────────────────────

    private record World(
            UUID patientUserId,
            UUID pastBooked,
            UUID futureBooked,
            UUID futureCancelled,
            UUID superseded,
            UUID replacement
    ) {
    }

    private List<UUID> ids(Page<AppointmentResponse> page) {
        return page.getContent().stream().map(AppointmentResponse::id).toList();
    }

    private World world() {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount patientAccount = users.save(new UserAccount(
                    "patient-" + unique + "@example.com", "hash", "Pat", "Ient", Role.PATIENT));
            PatientProfile patient = new PatientProfile(patientAccount);
            patient.setSkinType(SkinType.NORMAL);
            patients.save(patient);

            Appointment pastBooked = appointments.save(
                    new Appointment(patient, NOW.minus(2, ChronoUnit.HOURS)));

            Appointment futureBooked = appointments.save(
                    new Appointment(patient, NOW.plus(2, ChronoUnit.HOURS)));

            Appointment futureCancelled = appointments.save(
                    new Appointment(patient, NOW.plus(3, ChronoUnit.HOURS)));
            futureCancelled.cancel();
            appointments.save(futureCancelled);

            // The superseded original hides; its replacement stands.
            Appointment superseded = appointments.save(
                    new Appointment(patient, NOW.plus(4, ChronoUnit.HOURS)));
            Appointment replacement = appointments.save(
                    new Appointment(patient, NOW.plus(5, ChronoUnit.HOURS)));
            replacement.setReplaces(superseded);
            appointments.save(replacement);

            return new World(
                    patient.getUserId(),
                    pastBooked.getId(),
                    futureBooked.getId(),
                    futureCancelled.getId(),
                    superseded.getId(),
                    replacement.getId());
        });
    }

    // Two visits sharing one instant, so only id can order them.
    private UUID twinsAt(Instant scheduledAt) {
        return transactions.execute(status -> {
            String unique = UUID.randomUUID().toString().substring(0, 8);

            UserAccount account = users.save(new UserAccount(
                    "twins-" + unique + "@example.com", "hash", "Twin", "Case", Role.PATIENT));
            PatientProfile patient = new PatientProfile(account);
            patient.setSkinType(SkinType.NORMAL);
            patients.save(patient);

            appointments.save(new Appointment(patient, scheduledAt));
            appointments.save(new Appointment(patient, scheduledAt));

            return patient.getUserId();
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
