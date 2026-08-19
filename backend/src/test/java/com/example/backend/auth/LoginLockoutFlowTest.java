package com.example.backend.auth;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.security.Role;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class LoginLockoutFlowTest extends AbstractIntegrationTest {

    private static final String EMAIL = "lockout-flow@example.com";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserAccountRepository users;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @AfterEach
    void removeTestAccount() {
        users.findByEmailIgnoreCase(EMAIL).ifPresent(users::delete);
    }

    @Test
    void locksOutAfterFiveFailedAttemptsEvenWithTheCorrectPassword() throws Exception {
        users.save(new UserAccount(
                EMAIL,
                passwordEncoder.encode("correct-password"),
                "Test",
                "User",
                Role.PATIENT
        ));

        for (int i = 0; i < 5; i++) {
            attemptLogin("wrong-password");
        }

        UserAccount locked = users.findByEmailIgnoreCase(EMAIL).orElseThrow();
        assertThat(locked.isLocked(Instant.now())).isTrue();
        assertThat(locked.getLockoutStrikes()).isEqualTo(1);

        attemptLogin("correct-password");
    }

    @Test
    void successfulLoginClearsEarlierFailures() throws Exception {
        users.save(new UserAccount(
                EMAIL,
                passwordEncoder.encode("correct-password"),
                "Test",
                "User",
                Role.PATIENT
        ));

        for (int i = 0; i < 4; i++) {
            attemptLogin("wrong-password");
        }

        assertThat(users.findByEmailIgnoreCase(EMAIL).orElseThrow().getFailedLoginCount())
                .isEqualTo(4);

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body("correct-password")))
                .andExpect(status().isOk());

        UserAccount cleared = users.findByEmailIgnoreCase(EMAIL).orElseThrow();
        assertThat(cleared.getFailedLoginCount()).isZero();
        assertThat(cleared.isLocked(Instant.now())).isFalse();
    }

    private void attemptLogin(String password) throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(password)))
                .andExpect(status().isUnauthorized());
    }

    private String body(String password) {
        return """
                {
                  "email": "%s",
                  "password": "%s"
                }
                """.formatted(EMAIL, password);
    }
}
