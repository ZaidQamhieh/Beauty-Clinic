package com.example.backend.user;

import com.example.backend.AbstractIntegrationTest;
import com.example.backend.entities.UserAccount;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class UserAccountDetailsServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserDetailsService userDetailsService;

    @Autowired
    private UserAccountRepository users;

    @Test
    void loadsTheRoleAsAnAuthorityOutsideATransaction() {
        users.save(new UserAccount("doctor@clinic.com", "{bcrypt}hash", "Test User", Role.DOCTOR));

        UserDetails details = userDetailsService.loadUserByUsername("Doctor@Clinic.com");

        assertThat(details.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .containsExactly("ROLE_DOCTOR");
    }

    @Test
    void disabledAccountIsReportedAsDisabled() {
        UserAccount account = new UserAccount("retired@clinic.com", "{bcrypt}hash", "Test User", Role.DOCTOR);
        account.setStatus("DEACTIVATED");
        users.save(account);

        UserDetails details = userDetailsService.loadUserByUsername("retired@clinic.com");

        assertThat(details.isEnabled()).isFalse();
    }

    @Test
    void rejectsUnknownEmail() {
        assertThatThrownBy(() -> userDetailsService.loadUserByUsername("nobody@clinic.com"))
                .isInstanceOf(UsernameNotFoundException.class);
    }
}
