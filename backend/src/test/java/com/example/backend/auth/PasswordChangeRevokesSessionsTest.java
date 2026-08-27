package com.example.backend.auth;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.util.ArrayList;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// A new password signs every device out.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PasswordChangeRevokesSessionsTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private final List<String> createdEmails = new ArrayList<>();

    @AfterEach
    void removeTestAccounts() {
        createdEmails.forEach(email ->
                users.findByEmailIgnoreCase(email).ifPresent(users::delete));
        createdEmails.clear();
    }

    @Test
    void changingAPasswordEndsTheOtherDevicesSession() throws Exception {
        newAccount("pw-other@example.com", Role.PATIENT);
        Session phone = login("pw-other@example.com");
        Session laptop = login("pw-other@example.com");

        callOpen(laptop.accessToken()).andExpect(status().isOk());

        changePassword(phone.accessToken(), "password", "brand-new-pass1")
                .andExpect(status().isNoContent());

        callOpen(laptop.accessToken()).andExpect(status().isUnauthorized());
        refresh(laptop.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void changingAPasswordEndsTheCallersOwnSessionToo() throws Exception {
        newAccount("pw-self@example.com", Role.PATIENT);
        Session session = login("pw-self@example.com");

        changePassword(session.accessToken(), "password", "brand-new-pass1")
                .andExpect(status().isNoContent());

        callOpen(session.accessToken()).andExpect(status().isUnauthorized());
        refresh(session.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void theNewPasswordSignsBackIn() throws Exception {
        newAccount("pw-relogin@example.com", Role.PATIENT);
        Session session = login("pw-relogin@example.com");

        changePassword(session.accessToken(), "password", "brand-new-pass1")
                .andExpect(status().isNoContent());

        Session fresh = login("pw-relogin@example.com", "brand-new-pass1");
        callOpen(fresh.accessToken()).andExpect(status().isOk());
    }

    @Test
    void aRejectedPasswordChangeLeavesSessionsAlone() throws Exception {
        newAccount("pw-wrong@example.com", Role.PATIENT);
        Session phone = login("pw-wrong@example.com");
        Session laptop = login("pw-wrong@example.com");

        changePassword(phone.accessToken(), "not-the-password", "brand-new-pass1")
                .andExpect(status().isBadRequest());

        callOpen(phone.accessToken()).andExpect(status().isOk());
        callOpen(laptop.accessToken()).andExpect(status().isOk());
    }

    @Test
    void anAdminResetEndsTheOwnersSessions() throws Exception {
        UserAccount doctor = newAccount("pw-reset-target@example.com", Role.DOCTOR);
        newAccount("pw-reset-admin@example.com", Role.ADMIN);

        Session theirs = login("pw-reset-target@example.com");
        Session admin = login("pw-reset-admin@example.com");

        callOpen(theirs.accessToken()).andExpect(status().isOk());

        mockMvc.perform(put("/api/admin/accounts/" + doctor.getId())
                        .header("Authorization", "Bearer " + admin.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(accountBody("pw-reset-target@example.com", "reset-pass-9999")))
                .andExpect(status().isOk());

        callOpen(theirs.accessToken()).andExpect(status().isUnauthorized());
        callOpen(admin.accessToken()).andExpect(status().isOk());
    }

    @Test
    void anAdminEditWithoutAPasswordLeavesSessionsAlone() throws Exception {
        UserAccount doctor = newAccount("pw-edit-target@example.com", Role.DOCTOR);
        newAccount("pw-edit-admin@example.com", Role.ADMIN);

        Session theirs = login("pw-edit-target@example.com");
        Session admin = login("pw-edit-admin@example.com");

        mockMvc.perform(put("/api/admin/accounts/" + doctor.getId())
                        .header("Authorization", "Bearer " + admin.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(accountBody("pw-edit-target@example.com", null)))
                .andExpect(status().isOk());

        callOpen(theirs.accessToken()).andExpect(status().isOk());
    }

    private String accountBody(String email, String password) {
        String passwordField = password == null
                ? ""
                : "\"password\": \"%s\",".formatted(password);

        return """
                {
                  "email": "%s",
                  "firstName": "Test",
                  "lastName": "User",
                  "role": "DOCTOR",
                  %s
                  "doctorProfile": {
                    "specializations": ["DERMATOLOGY"],
                    "yearsOfExperience": 4
                  }
                }
                """.formatted(email, passwordField);
    }

    private ResultActions changePassword(
            String accessToken, String current, String next) throws Exception {
        return mockMvc.perform(put("/api/users/me/password")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"currentPassword": "%s", "newPassword": "%s"}
                        """.formatted(current, next)));
    }

    private ResultActions callOpen(String accessToken) throws Exception {
        return mockMvc.perform(get("/test/open")
                .header("Authorization", "Bearer " + accessToken));
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return mockMvc.perform(post("/api/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\": \"%s\"}".formatted(refreshToken)));
    }

    private UserAccount newAccount(String email, Role role) {
        createdEmails.add(email);
        return users.saveAndFlush(new UserAccount(
                email, passwordEncoder.encode("password"), "Test", "User", role));
    }

    private Session login(String email) throws Exception {
        return login(email, "password");
    }

    private Session login(String email, String password) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email": "%s", "password": "%s"}
                                """.formatted(email, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return new Session(
                JsonPath.read(body, "$.accessToken"),
                JsonPath.read(body, "$.refreshToken"));
    }

    private record Session(String accessToken, String refreshToken) {
    }
}
