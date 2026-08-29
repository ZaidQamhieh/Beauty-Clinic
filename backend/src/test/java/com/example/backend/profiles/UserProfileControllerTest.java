package com.example.backend.profiles;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.DoctorProfile;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.DoctorProfileRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class UserProfileControllerTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private DoctorProfileRepository doctors;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void unauthenticatedCannotReadProfile() throws Exception {
        mockMvc.perform(get("/api/users/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void patientReadsOwnProfile() throws Exception {
        UserAccount patient = newAccount("patient-read@test.com", Role.PATIENT);
        String token = login("patient-read@test.com");

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("patient-read@test.com"))
                .andExpect(jsonPath("$.role").value("PATIENT"));
    }

    @Test
    void doctorReadsOwnProfile() throws Exception {
        newAccount("doctor-read@test.com", Role.DOCTOR);
        String token = login("doctor-read@test.com");

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("doctor-read@test.com"))
                .andExpect(jsonPath("$.role").value("DOCTOR"));
    }

    @Test
    void adminReadsOwnProfile() throws Exception {
        newAccount("admin-read@test.com", Role.ADMIN);
        String token = login("admin-read@test.com");

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("admin-read@test.com"))
                .andExpect(jsonPath("$.role").value("ADMIN"));
    }

    @Test
    void unauthenticatedCannotUpdateProfile() throws Exception {
        mockMvc.perform(put("/api/users/me")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "Updated",
                                  "lastName": "Name",
                                  "phone": "+15551234567",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void patientUpdatesOwnProfile() throws Exception {
        newAccount("patient-update@test.com", Role.PATIENT);
        String token = login("patient-update@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "UpdatedFirst",
                                  "lastName": "UpdatedLast",
                                  "phone": "+25551111111",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firstName").value("UpdatedFirst"))
                .andExpect(jsonPath("$.lastName").value("UpdatedLast"))
                .andExpect(jsonPath("$.phone").value("+25551111111"))
                .andExpect(jsonPath("$.gender").value("MALE"));
    }

    @Test
    void patientCannotUpdateWithBlankFirstName() throws Exception {
        newAccount("patient-blank-fn@test.com", Role.PATIENT);
        String token = login("patient-blank-fn@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "",
                                  "lastName": "Last",
                                  "phone": "+25551222222",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotUpdateWithBlankLastName() throws Exception {
        newAccount("patient-blank-ln@test.com", Role.PATIENT);
        String token = login("patient-blank-ln@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "",
                                  "phone": "+25551333333",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotUpdateWithBlankPhone() throws Exception {
        newAccount("patient-blank-ph@test.com", Role.PATIENT);
        String token = login("patient-blank-ph@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotUpdateWithFutureDateOfBirth() throws Exception {
        newAccount("patient-future-dob@test.com", Role.PATIENT);
        String token = login("patient-future-dob@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25551444444",
                                  "dateOfBirth": "2030-01-01",
                                  "gender": "MALE"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCanUpdateImageUrl() throws Exception {
        newAccount("patient-img@test.com", Role.PATIENT);
        String token = login("patient-img@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25551555555",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE",
                                  "imageUrl": "https://example.com/image.jpg"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageUrl").value("https://example.com/image.jpg"));
    }

    @Test
    void patientCanClearImageUrl() throws Exception {
        newAccount("patient-clear-img@test.com", Role.PATIENT);
        String token = login("patient-clear-img@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25551666666",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE",
                                  "imageUrl": ""
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageUrl").doesNotExist());
    }

    @Test
    void patientCannotChangeEmail() throws Exception {
        newAccount("patient-email@test.com", Role.PATIENT);
        String token = login("patient-email@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25551777777",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE",
                                  "email": "newemail@example.com"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotChangeRole() throws Exception {
        newAccount("patient-role@test.com", Role.PATIENT);
        String token = login("patient-role@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25551888888",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE",
                                  "role": "ADMIN"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void doctorCanUpdateSpecializations() throws Exception {
        newAccount("doctor-spec@test.com", Role.DOCTOR);
        String token = login("doctor-spec@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "Dr",
                                  "lastName": "Smith",
                                  "phone": "+25552222222",
                                  "dateOfBirth": "1985-01-01",
                                  "gender": "MALE",
                                  "specializations": ["DERMATOLOGY"],
                                  "yearsOfExperience": 10
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.doctorProfile").isNotEmpty());
    }

    @Test
    void doctorCannotUpdateWithoutSpecializations() throws Exception {
        newAccount("doctor-no-spec@test.com", Role.DOCTOR);
        String token = login("doctor-no-spec@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "Dr",
                                  "lastName": "Smith",
                                  "phone": "+25552222222",
                                  "dateOfBirth": "1985-01-01",
                                  "gender": "MALE",
                                  "specializations": [],
                                  "yearsOfExperience": 10
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void doctorCannotUpdateWithoutYearsOfExperience() throws Exception {
        newAccount("doctor-no-years@test.com", Role.DOCTOR);
        String token = login("doctor-no-years@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "Dr",
                                  "lastName": "Smith",
                                  "phone": "+25552333333",
                                  "dateOfBirth": "1985-01-01",
                                  "gender": "MALE",
                                  "specializations": ["DERMATOLOGY"]
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotUpdateDoctorFields() throws Exception {
        newAccount("patient-doc-fields@test.com", Role.PATIENT);
        String token = login("patient-doc-fields@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25552444444",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "MALE",
                                  "specializations": ["DERMATOLOGY"]
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedCannotChangePassword() throws Exception {
        mockMvc.perform(put("/api/users/me/password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "old",
                                  "newPassword": "newpass123"
                                }
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void patientChangesOwnPassword() throws Exception {
        newAccount("patient-pwd@test.com", Role.PATIENT);
        String token = login("patient-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "password",
                                  "newPassword": "newpass1234"
                                }
                                """))
                .andExpect(status().isNoContent());
    }

    @Test
    void patientCannotChangePasswordWithWrongCurrent() throws Exception {
        newAccount("patient-wrong-pwd@test.com", Role.PATIENT);
        String token = login("patient-wrong-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "wrong",
                                  "newPassword": "newpass1234"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotChangePasswordWithBlankNew() throws Exception {
        newAccount("patient-blank-pwd@test.com", Role.PATIENT);
        String token = login("patient-blank-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "password",
                                  "newPassword": ""
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void patientCannotChangePasswordWithShortNew() throws Exception {
        newAccount("patient-short-pwd@test.com", Role.PATIENT);
        String token = login("patient-short-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "password",
                                  "newPassword": "short"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void doctorChangesOwnPassword() throws Exception {
        newAccount("doctor-pwd@test.com", Role.DOCTOR);
        String token = login("doctor-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "password",
                                  "newPassword": "newpass1234"
                                }
                                """))
                .andExpect(status().isNoContent());
    }

    @Test
    void adminChangesOwnPassword() throws Exception {
        newAccount("admin-pwd@test.com", Role.ADMIN);
        String token = login("admin-pwd@test.com");

        mockMvc.perform(put("/api/users/me/password")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "currentPassword": "password",
                                  "newPassword": "newpass1234"
                                }
                                """))
                .andExpect(status().isNoContent());
    }

    @Test
    void patientUpdatesGender() throws Exception {
        newAccount("patient-gender@test.com", Role.PATIENT);
        String token = login("patient-gender@test.com");

        mockMvc.perform(put("/api/users/me")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "firstName": "First",
                                  "lastName": "Last",
                                  "phone": "+25552555555",
                                  "dateOfBirth": "1990-01-01",
                                  "gender": "FEMALE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.gender").value("FEMALE"));
    }

    @Test
    void profileResponseDoesNotIncludePasswordHash() throws Exception {
        newAccount("patient-hash@test.com", Role.PATIENT);
        String token = login("patient-hash@test.com");

        MvcResult result = mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain("passwordHash");
    }

    @Test
    void profileResponseIncludesAllFields() throws Exception {
        newAccount("patient-all@test.com", Role.PATIENT);
        String token = login("patient-all@test.com");

        mockMvc.perform(get("/api/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").isNotEmpty())
                .andExpect(jsonPath("$.firstName").isNotEmpty())
                .andExpect(jsonPath("$.lastName").isNotEmpty())
                .andExpect(jsonPath("$.phone").isNotEmpty())
                .andExpect(jsonPath("$.dateOfBirth").isNotEmpty())
                .andExpect(jsonPath("$.gender").isNotEmpty())
                .andExpect(jsonPath("$.role").isNotEmpty());
    }

    private UserAccount newAccount(String email, Role role) {
        UserAccount account = new UserAccount(
                email,
                passwordEncoder.encode("password"),
                "Test",
                "User",
                role
        );
        account.setPhone("+12025551234");
        account.setDateOfBirth(LocalDate.of(1990, 1, 1));
        account.setGender(UserAccount.Gender.MALE);
        return users.save(account);
    }

    private String login(String email) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "password": "password"
                                }
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(body, "$.accessToken");
    }
}
