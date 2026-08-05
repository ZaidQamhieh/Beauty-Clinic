package com.example.backend.doctor;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.Doctor;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorRepository;
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
    private DoctorRepository doctors;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private UserAccount unregisteredDoctorAccount;
    private Doctor doctor;
    private String adminToken;
    private String doctorToken;
    private String otherDoctorToken;
    private String patientToken;

    @BeforeEach
    void setUp() throws Exception {
        unregisteredDoctorAccount = account("new-doc@clinic.com", Role.DOCTOR);

        doctor = doctors.save(new Doctor(account("doc@clinic.com", Role.DOCTOR)));
        doctor.setSpecialty("Dermatology");
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
                .andExpect(jsonPath("$.specialty").value("Dermatology"));
    }

    @Test
    void onlyAdminCanRegisterADoctorProfile() throws Exception {
        mockMvc.perform(post("/api/doctors")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerRequest(unregisteredDoctorAccount)))
                .andExpect(status().isForbidden());

        mockMvc.perform(post("/api/doctors")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerRequest(unregisteredDoctorAccount)))
                .andExpect(status().isCreated());
    }

    @Test
    void aDoctorEditsTheirOwnProfileButNotSomeoneElses() throws Exception {
        String body = """
                {"specialty": "Orthodontics", "licenseNumber": "L-1", "bio": "Bio"}
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
                .andExpect(jsonPath("$.specialty").value("Orthodontics"));
    }

    @Test
    void aDoctorSetsTheirOwnWorkingHoursButNotSomeoneElses() throws Exception {
        String body = """
                {"availability": [{"dayOfWeek": 1, "start": "09:00", "end": "17:00"}]}
                """;

        mockMvc.perform(put("/api/doctors/" + doctor.getUserId() + "/working-hours")
                        .header("Authorization", "Bearer " + otherDoctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());

        mockMvc.perform(put("/api/doctors/" + doctor.getUserId() + "/working-hours")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.availability[0].dayOfWeek").value(1));
    }

    @Test
    void workingHoursOutsideTheWeekAreRejected() throws Exception {
        String body = """
                {"availability": [{"dayOfWeek": 9, "start": "09:00", "end": "17:00"}]}
                """;

        mockMvc.perform(put("/api/doctors/" + doctor.getUserId() + "/working-hours")
                        .header("Authorization", "Bearer " + doctorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest());
    }

    private String registerRequest(UserAccount account) {
        return """
                {"userId": "%s", "specialty": "General", "licenseNumber": "L-0", "bio": "Bio"}
                """.formatted(account.getId());
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
