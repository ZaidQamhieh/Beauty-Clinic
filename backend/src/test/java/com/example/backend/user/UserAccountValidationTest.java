package com.example.backend.user;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import jakarta.validation.ConstraintViolationException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
class UserAccountValidationTest extends AbstractIntegrationTest {

    @Autowired
    private UserAccountRepository users;

    @Test
    void rejectsMalformedEmail() {
        UserAccount account = new UserAccount("not-an-email", "{bcrypt}hash", "Test User", Role.PATIENT);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }

    @Test
    void rejectsBlankPasswordHash() {
        UserAccount account = new UserAccount("someone@clinic.com", "  ", "Test User", Role.PATIENT);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }

    @Test
    void rejectsBlankFullName() {
        UserAccount account = new UserAccount("nameless@clinic.com", "{bcrypt}hash", "  ", Role.PATIENT);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }

    @Test
    void rejectsAccountWithNoRole() {
        UserAccount account = new UserAccount("roleless@clinic.com", "{bcrypt}hash", "Test User", null);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }
}
