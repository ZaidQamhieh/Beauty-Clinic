package com.example.backend.doctor;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.entities.DoctorProfile.Specialization;
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
class DoctorAccessTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private UserAccount unregisteredDoctorAccount;
    private DoctorProfile doctor;
    private String adminToken;
    private String doctorToken;
    private String otherDoctorToken;
    private String patientToken;

    @BeforeEach
    void setUp() throws Exception {
        unregisteredDoctorAccount = account("new-doc@clinic.com", Role.DOCTOR);

        doctor = doctors.save(new DoctorProfile(account("doc@clinic.com", Role.DOCTOR)));
        doctor.setSpecializations(List.of(Specialization.DERMATOLOGY));
        doctors.save(doctor);

        account("other-doc@clinic.com", Role.DOCTOR);
        account("someone@clinic.com", Role.PATIENT);
        account("admin@clinic.com", Role.ADMIN);

        adminToken = login("admin@clinic.com");
        doctorToken = login("doc@clinic.com");
        otherDoctorToken = login("other-doc@clinic.com");
        patientToken = login("someone@clinic.com");
    }

    @Test
    void anyAuthenticatedUserCanBrowseDoctors() throws Exception {
        mockMvc.perform(get("/api/doctors")
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/doctors/" + doctor.getUserId())
                        .header("Authorization", "Bearer " + patientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.specializations[0]").value("DERMATOLOGY"));
    }

    @Test
    void onlyAdminCanRegisterADoctorProfile() throws Exception {
        mockMvc.perform(post("/api/doctors/" + unregisteredDoctorAccount.getId())
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerRequest()))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/doctors/" + unregisteredDoctorAccount.getId())
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerRequest()))
                .andExpect(status().isCreated());
    }

    @Test
    void aDoctorEditsTheirOwnProfileButNotSomeoneElses() throws Exception {
        String body = """
                {"specializations": ["LASER_THERAPY"], "yearsOfExperience": 5}
                """;

        mockMvc.perform(put("/api/doctors/" + doctor.getUserId())
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/doctors/" + doctor.getUserId())
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.specializations[0]").value("LASER_THERAPY"));
    }

    @Test
    void aDoctorAddsTheirOwnAvailabilityButNotSomeoneElses() throws Exception {
        String body = """
                {"kind": "RECURRING", "dayOfWeek": "MONDAY", "startTime": "09:00", "endTime": "17:00",
                 "available": true, "effectiveFrom": "2026-01-01"}
                """;

        mockMvc.perform(post("/api/doctors/" + doctor.getUserId() + "/availability")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/doctors/" + doctor.getUserId() + "/availability")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.dayOfWeek").value("MONDAY"));
    }

    @Test
    void availabilityOutsideTheWeekIsRejected() throws Exception {
        String body = """
                {"kind": "RECURRING", "dayOfWeek": "FUNDAY", "startTime": "09:00", "endTime": "17:00",
                 "available": true, "effectiveFrom": "2026-01-01"}
                """;

        mockMvc.perform(post("/api/doctors/" + doctor.getUserId() + "/availability")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest());
    }

    // Nothing else rejects an inverted window: not the entity, not the schema.
    @Test
    void availabilityEndingBeforeItStartsIsRejected() throws Exception {
        String body = """
                {"kind": "RECURRING", "dayOfWeek": "MONDAY", "startTime": "17:00", "endTime": "09:00",
                 "available": true, "effectiveFrom": "2026-01-01"}
                """;

        mockMvc.perform(post("/api/doctors/" + doctor.getUserId() + "/availability")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors").isNotEmpty());
    }

    @Test
    void availabilityEndingExactlyWhenItStartsIsRejected() throws Exception {
        String body = """
                {"kind": "RECURRING", "dayOfWeek": "MONDAY", "startTime": "09:00", "endTime": "09:00",
                 "available": true, "effectiveFrom": "2026-01-01"}
                """;

        mockMvc.perform(post("/api/doctors/" + doctor.getUserId() + "/availability")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest());
    }

    // The column's CHECK would answer 409, which reads as a conflict, not bad input.
    @Test
    void negativeYearsOfExperienceIsRejectedByName() throws Exception {
        mockMvc.perform(put("/api/doctors/" + doctor.getUserId())
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"specializations": ["DERMATOLOGY"], "yearsOfExperience": -1}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.yearsOfExperience").exists());
    }

    private String registerRequest() {
        return """
                {"specializations": ["DERMATOLOGY"], "yearsOfExperience": 1}
                """;
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
