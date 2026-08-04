package com.example.backend.user;

import com.example.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class PasswordHashingTest extends AbstractIntegrationTest {

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void hashesWithBcryptAndNeverStoresPlaintext() {
        String encoded = passwordEncoder.encode("correct-horse");

        assertThat(encoded).startsWith("{bcrypt}").doesNotContain("correct-horse");
    }

    @Test
    void verifiesCorrectPasswordAndRejectsWrongOne() {
        String encoded = passwordEncoder.encode("correct-horse");

        assertThat(passwordEncoder.matches("correct-horse", encoded)).isTrue();
        assertThat(passwordEncoder.matches("wrong", encoded)).isFalse();
    }
}
