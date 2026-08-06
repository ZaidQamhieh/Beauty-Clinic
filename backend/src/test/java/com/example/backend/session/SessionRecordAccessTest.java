package com.example.backend.session;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.PatientProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SessionRecordAccessTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

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
    private PasswordEncoder passwordEncoder;

    private PatientProfile patient;
    private AppointmentSession session;
    private String treatingDoctorToken;
    private String otherDoctorToken;
    private String patientToken;

    @BeforeEach
    void setUp() throws Exception {
        DoctorProfile treatingDoctor = doctors.save(new DoctorProfile(account("treating@clinic.com", Role.DOCTOR)));
        doctors.save(new DoctorProfile(account("other@clinic.com", Role.DOCTOR)));

        patient = patients.save(new PatientProfile(account("patient@clinic.com", Role.PATIENT)));

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        Appointment appointment = appointments.save(new Appointment(patient, start));
        session = sessions.save(new AppointmentSession(
                appointment, treatingDoctor, TreatmentCategory.CONSULTATION, TreatmentName.CONSULTATION,
                new BigDecimal("40.00"), 30, start, start.plus(30, ChronoUnit.MINUTES)
        ));

        treatingDoctorToken = login("treating@clinic.com");
        otherDoctorToken = login("other@clinic.com");
        patientToken = login("patient@clinic.com");
    }

    @Test
    void theTreatingDoctorCanWriteAndReadSessionRecords() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.note").value("Mild dermatitis, topical cream, follow up in 2 weeks"));

        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].note").value("Mild dermatitis, topical cream, follow up in 2 weeks"));
    }

    @Test
    void aDoctorWithoutTheSessionCannotWriteOrReadSessionRecords() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + otherDoctorToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void thePatientReadsTheirOwnRecordsButCannotWriteThem() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].note").value("Mild dermatitis, topical cream, follow up in 2 weeks"));

        mockMvc.perform(post("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isForbidden());
    }

    @Test
    void amendingCreatesANewRecordPointingToTheOriginal() throws Exception {
        String body = mockMvc.perform(post("/api/patients/" + patient.getUserId() + "/session-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String originalId = JsonPath.read(body, "$.id");

        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/session-records/" + originalId + "/amend")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"note": "Contact dermatitis, steroid cream, corrected"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.note").value("Contact dermatitis, steroid cream, corrected"))
                .andExpect(jsonPath("$.amendsId").value(originalId));
    }

    private String createRequest() {
        return """
                {
                  "sessionId": "%s",
                  "note": "Mild dermatitis, topical cream, follow up in 2 weeks"
                }
                """.formatted(session.getId());
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(email, passwordEncoder.encode("password"), "Test", "User", role));
    }

    private String login(String email) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email": "%s", "password": "password"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.accessToken");
    }
}
