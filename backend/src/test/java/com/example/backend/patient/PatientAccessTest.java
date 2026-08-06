package com.example.backend.patient;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.PatientProfile.Allergy;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.PatientProfile;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;
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
import java.util.List;

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
    private PatientProfileRepository patients;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private AppointmentRepository appointments;

    @Autowired
    private AppointmentSessionRepository sessions;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private PatientProfile patient;
    private String patientToken;
    private String receptionToken;
    private String treatingDoctorToken;
    private String otherDoctorToken;

    @BeforeEach
    void setUp() throws Exception {
        UserAccount patientUser = account("owner@clinic.com", Role.PATIENT);
        patient = new PatientProfile(patientUser);
        patient.setAllergies(List.of(Allergy.LATEX));
        patients.save(patient);

        DoctorProfile treating = doctors.save(new DoctorProfile(account("treating@clinic.com", Role.DOCTOR)));
        doctors.save(new DoctorProfile(account("other@clinic.com", Role.DOCTOR)));
        account("desk@clinic.com", Role.RECEPTIONIST);

        Instant start = Instant.now().plus(1, ChronoUnit.DAYS);
        Appointment appointment = appointments.save(new Appointment(patient, start));
        sessions.save(new AppointmentSession(
                appointment, treating, TreatmentCategory.LASER, TreatmentName.LASER_HAIR_REMOVAL,
                new BigDecimal("120.00"), 45, start, start.plus(45, ChronoUnit.MINUTES)
        ));

        patientToken = login("owner@clinic.com");
        receptionToken = login("desk@clinic.com");
        treatingDoctorToken = login("treating@clinic.com");
        otherDoctorToken = login("other@clinic.com");
    }

    @Test
    void receptionReadsDemographicsButNeverAllergies() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getUserId())
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("Test"))
                .andExpect(jsonPath("$.allergies").doesNotExist());

        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + receptionToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void theTreatingDoctorReadsAndWritesClinicalData() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + treatingDoctorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies[0]").value("LATEX"));

        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"pregnantBreastfeeding": false, "allergies": ["LATEX", "IODINE"],
                                 "medications": [], "chronicConditions": []}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies[1]").value("IODINE"));
    }

    @Test
    void aDoctorWithoutAnAppointmentIsRefused() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + otherDoctorToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"pregnantBreastfeeding": false, "allergies": [], "medications": [], "chronicConditions": []}
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    void thePatientReadsTheirOwnRecordButCannotWriteIt() throws Exception {
        mockMvc.perform(get("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies[0]").value("LATEX"));

        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + patientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"pregnantBreastfeeding": false, "allergies": [], "medications": [], "chronicConditions": []}
                                """))
                .andExpect(status().isForbidden());
    }

    // An omitted list reached a NOT NULL column; an omitted flag recorded false.
    @Test
    void aPartialClinicalPutIsRejectedByFieldName() throws Exception {
        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"skinType": "DRY"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.allergies").exists())
                .andExpect(jsonPath("$.errors.medications").exists())
                .andExpect(jsonPath("$.errors.chronicConditions").exists())
                .andExpect(jsonPath("$.errors.pregnantBreastfeeding").exists());
    }

    // Clearing a list stays possible: [] is a statement, absence is not.
    @Test
    void anExplicitlyEmptyClinicalListIsAccepted() throws Exception {
        mockMvc.perform(put("/api/patients/" + patient.getUserId() + "/clinical")
                        .header("Authorization", "Bearer " + treatingDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"pregnantBreastfeeding": false, "allergies": [],
                                 "medications": [], "chronicConditions": []}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allergies").isEmpty());
    }

    @Test
    void aPatientCannotReachSomebodyElsesRecord() throws Exception {
        UserAccount strangerUser = account("stranger@clinic.com", Role.PATIENT);
        PatientProfile stranger = patients.save(new PatientProfile(strangerUser));

        mockMvc.perform(get("/api/patients/" + stranger.getUserId())
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/patients/" + stranger.getUserId() + "/clinical")
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
                                {"firstName": "New", "lastName": "Patient", "email": "new-patient@clinic.com"}
                                """))
                .andExpect(status().isForbidden());
    }

    private UserAccount account(String email, Role role) {
        return users.save(new UserAccount(
                email, passwordEncoder.encode("password"), "Test", "User", role
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
