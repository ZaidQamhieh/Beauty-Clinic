package com.example.backend.user;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.security.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class UserAccountRepositoryTest extends AbstractIntegrationTest {

    @Autowired
    private UserAccountRepository users;

    @Test
    void storesAndFindsByEmailRegardlessOfCase() {
        users.save(new UserAccount("Repo-Doctor@Clinic.com", "{bcrypt}hash", "Test User", Role.DOCTOR));

        assertThat(users.findByEmailIgnoreCase("repo-doctor@clinic.com")).isPresent();
        assertThat(users.findByEmailIgnoreCase("REPO-DOCTOR@CLINIC.COM")).isPresent();
    }

    @Test
    void normalisesEmailOnWrite() {
        UserAccount saved = users.save(new UserAccount("  Mixed@Case.COM ", "{bcrypt}hash", "Test User", Role.PATIENT));

        assertThat(saved.getEmail()).isEqualTo("mixed@case.com");
    }

    @Test
    void defaultsToEnabledWithGeneratedId() {
        UserAccount saved = users.save(new UserAccount("a@b.com", "{bcrypt}hash", "Test User", Role.ADMIN));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.isEnabled()).isTrue();
        assertThat(saved.getRole()).isEqualTo(Role.ADMIN);
    }
}
