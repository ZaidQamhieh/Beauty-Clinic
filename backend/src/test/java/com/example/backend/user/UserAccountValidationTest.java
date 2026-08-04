package com.example.backend.user;

import com.example.backend.AbstractIntegrationTest;
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
        UserAccount account = new UserAccount("not-an-email", "{bcrypt}hash", Role.PATIENT);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }

    @Test
    void rejectsBlankPasswordHash() {
        UserAccount account = new UserAccount("someone@clinic.com", "  ", Role.PATIENT);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }

    @Test
    void rejectsAccountWithNoRole() {
        UserAccount account = new UserAccount("roleless@clinic.com", "{bcrypt}hash", null);

        assertThatThrownBy(() -> users.saveAndFlush(account))
                .isInstanceOf(ConstraintViolationException.class);
    }
}
