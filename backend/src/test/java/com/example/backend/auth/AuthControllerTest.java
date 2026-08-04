package com.example.backend.auth;

import com.example.backend.security.Role;
import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import com.jayway.jsonpath.JsonPath;
import java.util.Set;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void loginReturnsBothTokens() throws Exception {
        users.save(new UserAccount(
                "login-test@example.com",
                passwordEncoder.encode("correct-password"),
                Set.of(Role.DOCTOR)
        ));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "login-test@example.com",
                                  "password": "correct-password"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());
    }

    @Test
    void blankEmailReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "",
                                  "password": "whatever"
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void blankRefreshTokenReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": ""}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidPasswordReturnsUnauthorized() throws Exception {
        users.save(new UserAccount(
                "invalid-login@example.com",
                passwordEncoder.encode("correct-password"),
                Set.of(Role.PATIENT)
        ));

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "email": "invalid-login@example.com",
                          "password": "wrong-password"
                        }
                        """))
        .andExpect(status().isUnauthorized());
    }

   @Test
    void refreshReturnsTokenPair() throws Exception {
        users.save(new UserAccount(
                "refresh@example.com",
                passwordEncoder.encode("password"),
                Set.of(Role.PATIENT)
        ));

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                "email": "refresh@example.com",
                                "password": "password"
                                }
                                """))
                .andReturn();

        String refreshToken = JsonPath.read(
                login.getResponse().getContentAsString(),
                "$.refreshToken"
        );

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());
    }

    @Test
    void logoutRejectsTheAccessTokenOnItsNextUse() throws Exception {
        users.save(new UserAccount(
                "logout@example.com",
                passwordEncoder.encode("password"),
                Set.of(Role.PATIENT)
        ));

        MvcResult login = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "logout@example.com",
                                  "password": "password"
                                }
                                """))
                .andReturn();

        String body = login.getResponse().getContentAsString();
        String accessToken = JsonPath.read(body, "$.accessToken");
        String refreshToken = JsonPath.read(body, "$.refreshToken");

        // Sanity check: the access token works on a protected endpoint
        // before logout.
        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isNoContent());

        // The very next request with the same access token is rejected,
        // even though the token itself hasn't expired yet.
        mockMvc.perform(get("/test/open")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void locksOutAfterFiveFailedAttemptsEvenWithTheCorrectPassword() throws Exception {
        users.save(new UserAccount(
                "lockout@example.com",
                passwordEncoder.encode("correct-password"),
                Set.of(Role.PATIENT)
        ));

        for (int i = 0; i < 5; i++) {
            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "email": "lockout@example.com",
                                      "password": "wrong-password"
                                    }
                                    """))
                    .andExpect(status().isUnauthorized());
        }

        // The 6th attempt is rejected even with the correct password.
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "lockout@example.com",
                                  "password": "correct-password"
                                }
                                """))
                .andExpect(status().isUnauthorized());
    }
}
