package com.example.backend.auth;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.security.Role;
import com.example.backend.user.UserAccount;
import com.example.backend.user.UserAccountRepository;
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

/*
  Deliberately NOT @Transactional.

  Lockout counting only works if a failed attempt survives the rollback of
  the login that produced it, so every attempt here has to commit the way a
  real request does. Wrapping the class in a test transaction would let all
  six attempts share one uncommitted transaction and pass even when the
  counting is broken.
 */
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
                Role.PATIENT
        ));

        for (int i = 0; i < 5; i++) {
            attemptLogin("wrong-password");
        }

        // Each failure was counted despite the login being rejected.
        UserAccount locked = users.findByEmailIgnoreCase(EMAIL).orElseThrow();
        assertThat(locked.isLocked(Instant.now())).isTrue();
        assertThat(locked.getLockoutStrikes()).isEqualTo(1);

        // So the 6th attempt fails even with the right password.
        attemptLogin("correct-password");
    }

    @Test
    void successfulLoginClearsEarlierFailures() throws Exception {
        users.save(new UserAccount(
                EMAIL,
                passwordEncoder.encode("correct-password"),
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
