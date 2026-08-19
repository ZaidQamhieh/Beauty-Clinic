package com.example.backend.accounts;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AdminAccountControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCreatesAReceptionistAccount() throws Exception {
        mockMvc.perform(post("/api/admin/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reception@example.com",
                                  "password": "temporary-password",
                                  "phone": "+15551234567",
                                  "firstName": "Reception",
                                  "lastName": "User",
                                  "dateOfBirth": "1990-01-02",
                                  "gender": "FEMALE",
                                  "role": "RECEPTIONIST"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("reception@example.com"))
                .andExpect(jsonPath("$.phone").value("+15551234567"))
                .andExpect(jsonPath("$.firstName").value("Reception"))
                .andExpect(jsonPath("$.lastName").value("User"))
                .andExpect(jsonPath("$.dateOfBirth").value("1990-01-02"))
                .andExpect(jsonPath("$.gender").value("FEMALE"))
                .andExpect(jsonPath("$.role").value("RECEPTIONIST"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        UserAccount account = users.findByEmailIgnoreCase("reception@example.com").orElseThrow();
        assertThat(account.getFirstName()).isEqualTo("Reception");
        assertThat(account.getLastName()).isEqualTo("User");
        assertThat(passwordEncoder.matches("temporary-password", account.getPasswordHash())).isTrue();

        mockMvc.perform(get("/api/admin/accounts")
                        .param("role", "RECEPTIONIST"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].email").value("reception@example.com"))
                .andExpect(jsonPath("$[0].role").value("RECEPTIONIST"));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCreatesADoctorAccountAndProfile() throws Exception {
        mockMvc.perform(post("/api/admin/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "doctor@example.com",
                                  "password": "temporary-password",
                                  "firstName": "Doctor",
                                  "lastName": "User",
                                  "role": "DOCTOR",
                                  "doctorProfile": {
                                    "specializations": ["DERMATOLOGY"],
                                    "yearsOfExperience": 8
                                  }
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.role").value("DOCTOR"))
                .andExpect(jsonPath("$.doctorProfile.specializations[0]").value("DERMATOLOGY"))
                .andExpect(jsonPath("$.doctorProfile.yearsOfExperience").value(8));

        UserAccount account = users.findByEmailIgnoreCase("doctor@example.com").orElseThrow();
        DoctorProfile profile = doctors.findById(account.getId()).orElseThrow();
        assertThat(profile.getYearsOfExperience()).isEqualTo(8);
        assertThat(profile.getSpecializations())
                .containsExactly(DoctorProfile.Specialization.DERMATOLOGY);
    }

    @Test
    @WithMockUser(roles = "DOCTOR")
    void nonAdminsCannotCreateAccounts() throws Exception {
        mockMvc.perform(post("/api/admin/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "reception@example.com",
                                  "password": "temporary-password",
                                  "firstName": "Reception",
                                  "lastName": "User",
                                  "role": "RECEPTIONIST"
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void duplicateEmailIsRejected() throws Exception {
        mockMvc.perform(post("/api/admin/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "duplicate@example.com",
                                  "password": "temporary-password",
                                  "firstName": "First",
                                  "lastName": "User",
                                  "role": "DOCTOR",
                                  "doctorProfile": {}
                                }
                                """))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/admin/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "duplicate@example.com",
                                  "password": "temporary-password",
                                  "firstName": "Second",
                                  "lastName": "User",
                                  "role": "RECEPTIONIST"
                                }
                                """))
                .andExpect(status().isConflict());
    }
}
