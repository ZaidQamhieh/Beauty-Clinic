package com.example.backend.treatment;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.ClinicService;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.Patient;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.ClinicServiceRepository;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.repositories.PatientRepository;
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
class TreatmentRecordAccessTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorRepository doctors;

    @Autowired
    private PatientRepository patients;

    @Autowired
    private ClinicServiceRepository services;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private Patient patient;
    private Appointment appointment;
    private String treatingDoctorToken;
    private String otherDoctorToken;
    private String patientToken;
    private String adminToken;

    @BeforeEach
    void setUp() throws Exception {
        Doctor treatingDoctor = doctors.save(new Doctor(account("treating@clinic.com", Role.DOCTOR)));
        doctors.save(new Doctor(account("other@clinic.com", Role.DOCTOR)));
        account("admin@clinic.com", Role.ADMIN);

        ClinicService service = services.save(new ClinicService("Consult", 30, new BigDecimal("40.00")));

        patient = new Patient("Amal", "Nasser");
        patient.setUser(account("patient@clinic.com", Role.PATIENT));
        patients.save(patient);

        appointment = appointments.save(new Appointment(
                patient, treatingDoctor, service,
                Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(30, ChronoUnit.MINUTES)
        ));

        treatingDoctorToken = login("treating@clinic.com");
        otherDoctorToken = login("other@clinic.com");
        patientToken = login("patient@clinic.com");
        adminToken = login("admin@clinic.com");
    }

    @Test
    void theTreatingDoctorCanWriteAndReadTreatmentRecords() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.diagnosis").value("Mild dermatitis"));

        mockMvc.perform(get("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].diagnosis").value("Mild dermatitis"));
    }

    @Test
    void aDoctorWithoutAnAppointmentCannotWriteOrReadTreatmentRecords() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + otherDoctorToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void thePatientReadsTheirOwnRecordsButCannotWriteThem() throws Exception {
        mockMvc.perform(post("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].diagnosis").value("Mild dermatitis"));

        mockMvc.perform(post("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isForbidden());
    }

    @Test
    void amendingCreatesANewRecordPointingToTheOriginal() throws Exception {
        String body = mockMvc.perform(post("/api/patients/" + patient.getId() + "/treatment-records")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(createRequest()))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String originalId = JsonPath.read(body, "$.id");

        mockMvc.perform(put("/api/patients/" + patient.getId() + "/treatment-records/" + originalId + "/amend")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"diagnosis": "Contact dermatitis", "treatment": "Steroid cream", "notes": "Corrected"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.diagnosis").value("Contact dermatitis"))
                .andExpect(jsonPath("$.amendsId").value(originalId));
    }

    private String createRequest() {
        return """
                {
                  "appointmentId": "%s",
                  "diagnosis": "Mild dermatitis",
                  "treatment": "Topical cream",
                  "notes": "Follow up in 2 weeks"
                }
                """.formatted(appointment.getId());
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(email, passwordEncoder.encode("password"), "Test User", role));
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
