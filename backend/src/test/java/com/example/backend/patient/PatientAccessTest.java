package com.example.backend.patient;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Appointment;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.entities.ClinicService;
import com.example.backend.repositories.ClinicServiceRepository;
import com.example.backend.entities.Doctor;
import com.example.backend.repositories.DoctorRepository;
import com.example.backend.entities.Patient;
import com.example.backend.repositories.PatientRepository;
import com.example.backend.security.Role;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
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
class PatientAccessTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PatientRepository patients;

    @Autowired
    private DoctorRepository doctors;

    @Autowired
    private ClinicServiceRepository services;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private Patient patient;
    private String patientToken;
    private String receptionToken;
    private String treatingDoctorToken;
    private String otherDoctorToken;

    @BeforeEach
    void setUp() throws Exception {
        UserAccount patientUser = account("owner@clinic.com", Role.PATIENT);
        patient = new Patient("Amal", "Nasser");
        patient.setUser(patientUser);
        patient.setAllergies("latex");
        patients.save(patient);

        Doctor treating = doctors.save(new Doctor(account("treating@clinic.com", Role.DOCTOR)));
        doctors.save(new Doctor(account("other@clinic.com", Role.DOCTOR)));
        account("desk@clinic.com", Role.RECEPTIONIST);

        ClinicService laser = services.save(
                new ClinicService("Laser", 45, new BigDecimal("120.00"))
        );
        appointments.save(new Appointment(
                patient, treating, laser,
                Instant.now().plus(1, ChronoUnit.DAYS),
                Instant.now().plus(1, ChronoUnit.DAYS).plus(45, ChronoUnit.MINUTES)
        ));

        patientToken = login("owner@clinic.com");
        receptionToken = login("desk@clinic.com");
        treatingDoctorToken = login("treating@clinic.com");
        otherDoctorToken = login("other@clinic.com");
    }

    @Test
    void receptionReadsDemographicsButNeverAllergies() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getId())
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("Amal"))
                .andExpect(jsonPath("$.allergies").doesNotExist());

        mockMvc.perform(get("/api/patients/" + patient.getId() + "/clinical")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void theTreatingDoctorReadsAndWritesClinicalData() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getId() + "/clinical")
                        .header("Authorization", "Bearer " + treatingDoctorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies").value("latex"));

        mockMvc.perform(put("/api/patients/" + patient.getId() + "/allergies")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"allergies": "latex, iodine"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies").value("latex, iodine"));
    }

    @Test
    void aDoctorWithoutAnAppointmentIsRefused() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getId() + "/clinical")
                        .header("Authorization", "Bearer " + otherDoctorToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/patients/" + patient.getId() + "/allergies")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"allergies": "anything"}
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    void thePatientReadsTheirOwnRecordButCannotWriteIt() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getId() + "/clinical")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies").value("latex"));

        mockMvc.perform(put("/api/patients/" + patient.getId() + "/allergies")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"allergies": "none"}
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    void aPatientCannotReachSomebodyElsesRecord() throws Exception {
        Patient stranger = patients.save(new Patient("Rana", "Haddad"));

        mockMvc.perform(get("/api/patients/" + stranger.getId())
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/patients/" + stranger.getId() + "/clinical")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void aPatientCannotRegisterOrSearchPatients() throws Exception {
        mockMvc.perform(get("/api/patients")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/patients")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"firstName": "New", "lastName": "Patient"}
                                """))
                .andExpect(status().isForbidden());
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(
                email, passwordEncoder.encode("password"), "Test User", role
        ));
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
