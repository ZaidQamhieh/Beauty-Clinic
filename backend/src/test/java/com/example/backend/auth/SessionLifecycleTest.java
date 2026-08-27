package com.example.backend.auth;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
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

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Every way a session stops being live.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SessionLifecycleTest extends AbstractIntegrationTest {

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
    void aRequestWithoutATokenIsRejected() throws Exception {
        mockMvc.perform(get("/test/open"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aGarbageBearerTokenIsRejected() throws Exception {
        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer not-a-jwt"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aDisabledAccountLosesItsLiveAccessToken() throws Exception {
        UserAccount account = newAccount("disabled-session@example.com", Role.PATIENT);
        Session session = login("disabled-session@example.com");

        callOpen(session.accessToken()).andExpect(status().isOk());

        account.setStatus(AccountStatus.DEACTIVATED);
        users.saveAndFlush(account);

        callOpen(session.accessToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void aDisabledAccountCannotRefreshEither() throws Exception {
        UserAccount account = newAccount("disabled-refresh@example.com", Role.PATIENT);
        Session session = login("disabled-refresh@example.com");

        account.setStatus(AccountStatus.DEACTIVATED);
        users.saveAndFlush(account);

        refresh(session.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void aRoleChangeInvalidatesTheTokenThatCarriesTheOldRole() throws Exception {
        UserAccount account = newAccount("role-change@example.com", Role.PATIENT);
        Session session = login("role-change@example.com");

        account.setRole(Role.DOCTOR);
        users.saveAndFlush(account);

        callOpen(session.accessToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void refreshingAfterARoleChangeMintsTheNewRole() throws Exception {
        UserAccount account = newAccount("role-refresh@example.com", Role.PATIENT);
        Session session = login("role-refresh@example.com");

        account.setRole(Role.DOCTOR);
        users.saveAndFlush(account);

        String body = refresh(session.refreshToken())
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        assertThat((String) JsonPath.read(body, "$.role")).isEqualTo("DOCTOR");

        String rotatedAccess = JsonPath.read(body, "$.accessToken");
        mockMvc.perform(get("/test/meta/doctor")
                        .header("Authorization", "Bearer " + rotatedAccess))
                .andExpect(status().isOk());
    }

    @Test
    void aDeletedAccountLosesItsLiveAccessToken() throws Exception {
        UserAccount account = newAccount("deleted-session@example.com", Role.PATIENT);
        Session session = login("deleted-session@example.com");

        users.delete(account);
        users.flush();

        callOpen(session.accessToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void loggingOutDoesNotTouchTheOtherDevicesSession() throws Exception {
        newAccount("two-devices@example.com", Role.PATIENT);
        Session first = login("two-devices@example.com");
        Session second = login("two-devices@example.com");

        assertThat(first.refreshToken()).isNotEqualTo(second.refreshToken());

        logout(first.refreshToken()).andExpect(status().isNoContent());

        callOpen(first.accessToken()).andExpect(status().isUnauthorized());
        callOpen(second.accessToken()).andExpect(status().isOk());
    }

    @Test
    void aRotatedRefreshTokenCannotBeReplayed() throws Exception {
        newAccount("replay@example.com", Role.PATIENT);
        Session session = login("replay@example.com");

        refresh(session.refreshToken()).andExpect(status().isOk());
        refresh(session.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void refreshingAfterLogoutIsRejected() throws Exception {
        newAccount("logout-refresh@example.com", Role.PATIENT);
        Session session = login("logout-refresh@example.com");

        logout(session.refreshToken()).andExpect(status().isNoContent());
        refresh(session.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    void loggingOutAnUnknownTokenSaysNothingAboutIt() throws Exception {
        logout("never-issued-" + UUID.randomUUID())
                .andExpect(status().isNoContent());
    }

    @Test
    void loggingOutTwiceIsHarmless() throws Exception {
        newAccount("double-logout@example.com", Role.PATIENT);
        Session session = login("double-logout@example.com");

        logout(session.refreshToken()).andExpect(status().isNoContent());
        logout(session.refreshToken()).andExpect(status().isNoContent());
    }

    @Test
    void aSignedInPatientHittingStaffOnlyGetsForbiddenNotUnauthorized() throws Exception {
        newAccount("wrong-role@example.com", Role.PATIENT);
        Session session = login("wrong-role@example.com");

        mockMvc.perform(get("/test/meta/staff")
                        .header("Authorization", "Bearer " + session.accessToken()))
                .andExpect(status().isForbidden());
    }

    @Test
    void repeatedLoginsIssueIndependentSessions() throws Exception {
        newAccount("repeat-login@example.com", Role.PATIENT);
        Session first = login("repeat-login@example.com");
        Session second = login("repeat-login@example.com");

        callOpen(first.accessToken()).andExpect(status().isOk());
        callOpen(second.accessToken()).andExpect(status().isOk());
        assertThat(first.accessToken()).isNotEqualTo(second.accessToken());
    }

    private UserAccount newAccount(String email, Role role) {
        createdEmails.add(email);
        return users.saveAndFlush(new UserAccount(
                email,
                passwordEncoder.encode("password"),
                "Test",
                "User",
                role
        ));
    }

    private org.springframework.test.web.servlet.ResultActions callOpen(String accessToken)
            throws Exception {
        return mockMvc.perform(get("/test/open")
                .header("Authorization", "Bearer " + accessToken));
    }

    private org.springframework.test.web.servlet.ResultActions refresh(String refreshToken)
            throws Exception {
        return mockMvc.perform(post("/api/auth/refresh")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\": \"%s\"}".formatted(refreshToken)));
    }

    private org.springframework.test.web.servlet.ResultActions logout(String refreshToken)
            throws Exception {
        return mockMvc.perform(post("/api/auth/logout")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\": \"%s\"}".formatted(refreshToken)));
    }

    private Session login(String email) throws Exception {
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

        return new Session(
                JsonPath.read(body, "$.accessToken"),
                JsonPath.read(body, "$.refreshToken"));
    }

    private record Session(String accessToken, String refreshToken) {
    }
}
