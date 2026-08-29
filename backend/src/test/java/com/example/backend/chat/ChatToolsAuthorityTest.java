package com.example.backend.chat;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
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
import com.example.backend.services.AccessTokenService;
import com.example.backend.security.Role;
import com.example.backend.services.ClinicTools;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class ChatToolsAuthorityTest extends AbstractIntegrationTest {

    private static final LocalDate DAY = LocalDate.now(ZoneOffset.UTC).plusDays(4);

    @Autowired
    private ClinicTools tools;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PatientProfileRepository patients;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private DoctorAvailabilityRepository availability;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private AppointmentSessionRepository sessions;

    @Autowired
    private TransactionTemplate transactions;

    private UUID doctorId;
    private UUID patientId;
    private UUID otherPatientId;

    @BeforeEach
    void setUpFixture() {
        String unique = UUID.randomUUID().toString().substring(0, 8);

        doctorId = transactions.execute(status -> {
            UserAccount account = users.save(new UserAccount(
                    "chat-doc-" + unique + "@example.com", "hash", "Dr", "Chat", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(account);
            profile.setSpecializations(
                    new ArrayList<>(TreatmentName.CONSULTATION.category().qualifying()));
            doctors.save(profile);

            DoctorAvailability open = new DoctorAvailability(
                    profile, AvailabilityKind.MODIFIED, null,
                    LocalTime.of(0, 0), LocalTime.of(23, 59), DAY);
            open.setEffectiveTo(DAY);
            availability.save(open);

            return account.getId();
        });

        patientId = newPatient("chat-patient-" + unique + "@example.com");
        otherPatientId = newPatient("chat-other-" + unique + "@example.com");
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private UUID newPatient(String email) {
        return transactions.execute(status -> {
            UserAccount account = users.save(
                    new UserAccount(email, "hash", "Chat", "Patient", Role.PATIENT));
            PatientProfile profile = new PatientProfile(account);
            profile.setSkinType(SkinType.NORMAL);
            patients.save(profile);
            return account.getId();
        });
    }

    private void actAs(UUID userId, Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, userId.toString())
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new JwtAuthenticationToken(token, List.of(role.authority())));
    }

    private Instant at(int hour) {
        return DAY.atTime(LocalTime.of(hour, 0)).toInstant(ZoneOffset.UTC);
    }

    private void bookVisitFor(UUID owner, int hour) {
        transactions.execute(status -> {
            PatientProfile profile = patients.findById(owner).orElseThrow();
            Appointment appointment = appointments.save(new Appointment(profile, at(hour)));
            sessions.save(new AppointmentSession(
                    appointment, doctors.findById(doctorId).orElseThrow(),
                    TreatmentName.CONSULTATION.category(), TreatmentName.CONSULTATION,
                    new BigDecimal("100.00"), 20, at(hour), at(hour).plusSeconds(1200)));
            return appointment.getId();
        });
    }

    private ClinicTools.Pick pickAt(int hour) {
        return new ClinicTools.Pick(
                TreatmentName.CONSULTATION, doctorId.toString(), at(hour).toString());
    }

    @Test
    void confirmingBooksTheStoredQuoteAndIgnoresResentPicks() {
        actAs(patientId, Role.PATIENT);

        tools.book(List.of(pickAt(10)), false);

        String booked = tools.book(List.of(pickAt(15)), true);

        assertThat(booked).startsWith("Booked.");

        List<AppointmentSession> mine = transactions.execute(status ->
                sessions.findAll().stream()
                        .filter(session -> patientId.equals(session.getPatientUserId()))
                        .toList());

        assertThat(mine).hasSize(1);
        assertThat(mine.getFirst().getStartTime()).isEqualTo(at(10));
    }

    @Test
    void confirmingWithoutAQuoteRefuses() {
        actAs(patientId, Role.PATIENT);

        String answer = tools.book(List.of(pickAt(10)), true);

        assertThat(answer).contains("Nothing has been quoted");
    }

    @Test
    void aQuoteBelongsToTheCallerAlone() {
        actAs(patientId, Role.PATIENT);
        tools.book(List.of(pickAt(10)), false);

        actAs(otherPatientId, Role.PATIENT);
        String answer = tools.book(List.of(pickAt(10)), true);

        assertThat(answer).contains("Nothing has been quoted");
    }

    @Test
    void visitsNeverReachAnotherPatientsAppointments() {
        bookVisitFor(otherPatientId, 12);

        actAs(patientId, Role.PATIENT);
        String mine = tools.myVisits();

        assertThat(mine).contains("no upcoming appointments");
    }

    @Test
    void visitsShowOnlyTheCallersOwnAppointments() {
        bookVisitFor(patientId, 13);
        bookVisitFor(otherPatientId, 14);

        actAs(patientId, Role.PATIENT);
        String mine = tools.myVisits();

        assertThat(mine).contains(at(13).toString());
        assertThat(mine).doesNotContain(at(14).toString());
    }
}
