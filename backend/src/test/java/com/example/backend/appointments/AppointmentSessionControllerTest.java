package com.example.backend.appointments;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.dtos.AddSessionRequest;
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
import com.example.backend.security.Role;
import com.example.backend.services.AccessTokenService;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.security.core.context.SecurityContextHolder.getContext;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AppointmentSessionControllerTest extends AbstractIntegrationTest {

    private static final LocalDate DAY = LocalDate.now(ZoneOffset.UTC).plusDays(5);

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AppointmentRepository appointmentRepository;

    @Autowired
    private AppointmentSessionRepository sessionRepository;

    @Autowired
    private DoctorProfileRepository doctorProfileRepository;

    @Autowired
    private PatientProfileRepository patientProfileRepository;

    @Autowired
    private UserAccountRepository userAccountRepository;

    @Autowired
    private DoctorAvailabilityRepository availabilityRepository;

    @Autowired
    private TransactionTemplate transactions;

    private JwtAuthenticationToken staffToken;
    private JwtAuthenticationToken patientToken;
    private JwtAuthenticationToken otherPatientToken;
    private UUID appointmentId;
    private UUID patientId;
    private UUID doctorId;

    @BeforeEach
    void setupFixture() {
        String unique = UUID.randomUUID().toString().substring(0, 8);

        doctorId = transactions.execute(status -> {
            UserAccount doc = userAccountRepository.save(
                    new UserAccount("doc-" + unique + "@example.com", "hash",
                            "Dr", "Test", Role.DOCTOR));
            DoctorProfile profile = new DoctorProfile(doc);
            var qualifications = new java.util.LinkedHashSet<>(TreatmentName.CONSULTATION.category().qualifying());
            qualifications.addAll(TreatmentName.HYDRAFACIAL.category().qualifying());
            profile.setSpecializations(new java.util.ArrayList<>(qualifications));
            doctorProfileRepository.save(profile);

            DoctorAvailability avail = new DoctorAvailability(
                    profile, AvailabilityKind.MODIFIED, null,
                    LocalTime.of(0, 0), LocalTime.of(23, 59), DAY);
            avail.setEffectiveTo(DAY);
            availabilityRepository.save(avail);

            return doc.getId();
        });

        patientId = transactions.execute(status -> {
            UserAccount patient = userAccountRepository.save(
                    new UserAccount("patient-" + unique + "@example.com", "hash",
                            "Patient", "User", Role.PATIENT));
            PatientProfile profile = new PatientProfile(patient);
            profile.setSkinType(SkinType.NORMAL);
            patientProfileRepository.save(profile);
            return patient.getId();
        });

        UUID otherPatientId = transactions.execute(status -> {
            UserAccount patient = userAccountRepository.save(
                    new UserAccount("other-" + unique + "@example.com", "hash",
                            "Other", "Patient", Role.PATIENT));
            PatientProfile profile = new PatientProfile(patient);
            profile.setSkinType(SkinType.NORMAL);
            patientProfileRepository.save(profile);
            return patient.getId();
        });

        appointmentId = transactions.execute(status -> {
            PatientProfile patient = patientProfileRepository.findById(patientId).orElseThrow();
            Appointment appointment = appointmentRepository.save(
                    new Appointment(patient, at(10, 0)));

            AppointmentSession session = sessionRepository.save(new AppointmentSession(
                    appointment, doctorProfileRepository.findById(doctorId).orElseThrow(),
                    TreatmentName.CONSULTATION.category(), TreatmentName.CONSULTATION,
                    new BigDecimal("100.00"), 20, at(10, 0), at(10, 20)));

            return appointment.getId();
        });

        UUID staffId = transactions.execute(status -> userAccountRepository.save(
                new UserAccount("staff-" + unique + "@example.com", "hash",
                        "Front", "Desk", Role.RECEPTIONIST)).getId());

        staffToken = createToken(staffId, Role.RECEPTIONIST);
        patientToken = createToken(patientId, Role.PATIENT);
        otherPatientToken = createToken(otherPatientId, Role.PATIENT);
    }

    @AfterEach
    void clearContext() {
        getContext().setAuthentication(null);
    }


    @Test
    void cancelSessionStaffOrOwner() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/cancel")
                .with(authentication(patientToken)))
                .andExpect(status().isOk());
    }

    @Test
    void cancelSessionRejectsOtherPatient() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/cancel")
                .with(authentication(otherPatientToken)))
                .andExpect(status().isForbidden());
    }


    private java.time.Instant at(int hour, int minute) {
        return DAY.atTime(LocalTime.of(hour, minute)).toInstant(ZoneOffset.UTC);
    }

    private JwtAuthenticationToken createToken(UUID userId, Role role) {
        Jwt token = Jwt.withTokenValue("test")
                .header("alg", "none")
                .claim(AccessTokenService.USER_ID_CLAIM, userId.toString())
                .build();

        return new JwtAuthenticationToken(token, List.of(role.authority()));
    }
    @Test
    void addSessionAllowsStaff() throws Exception {
        AddSessionRequest request = new AddSessionRequest(doctorId, TreatmentName.HYDRAFACIAL, at(11, 0));

        mockMvc.perform(post("/api/appointments/" + appointmentId + "/sessions")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request))
                .with(authentication(staffToken)))
                .andExpect(status().isCreated());
    }

    @Test
    void addSessionRejectsPatient() throws Exception {
        AddSessionRequest request = new AddSessionRequest(doctorId, TreatmentName.CONSULTATION, at(11, 0));

        mockMvc.perform(post("/api/appointments/" + appointmentId + "/sessions")
                .contentType("application/json")
                .content(objectMapper.writeValueAsString(request))
                .with(authentication(patientToken)))
                .andExpect(status().isForbidden());
    }

    @Test
    void markAttendedRejectsPatient() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/attended")
                .with(authentication(patientToken)))
                .andExpect(status().isForbidden());
    }

    @Test
    void markNoShowRejectsPatient() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/no-show")
                .with(authentication(patientToken)))
                .andExpect(status().isForbidden());
    }

    // Staff clear authorization; the session has not started yet.
    @Test
    void markAttendedRejectsSessionThatHasNotStarted() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/attended")
                .with(authentication(staffToken)))
                .andExpect(status().isConflict());
    }

    @Test
    void markNoShowRejectsSessionThatHasNotStarted() throws Exception {
        AppointmentSession session = sessionRepository.findByAppointmentId(appointmentId)
                .stream().findFirst().orElseThrow();

        mockMvc.perform(put("/api/appointments/" + appointmentId + "/sessions/" + session.getId() + "/no-show")
                .with(authentication(staffToken)))
                .andExpect(status().isConflict());
    }
}
