package com.example.backend.security;

import com.example.backend.entities.UserAccount;
import com.example.backend.entities.UserAccount.AccountStatus;
import com.example.backend.repositories.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
class AdminUserSeeder implements ApplicationRunner {

    private final UserAccountRepository users;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.seed-admin.enabled:true}")
    private boolean enabled;

    @Value("${app.seed-admin.email:admin@clinic.com}")
    private String email;

    @Value("${app.seed-admin.password:password123}")
    private String password;

    @Value("${app.seed-admin.first-name:Admin}")
    private String firstName;

    @Value("${app.seed-admin.last-name:User}")
    private String lastName;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            return;
        }

        users.findByEmailIgnoreCase(email)
                .ifPresentOrElse(this::initializeExistingAdminPassword, this::createAdmin);
    }

    private void initializeExistingAdminPassword(UserAccount account) {
        if (hasText(account.getPasswordHash())) {
            return;
        }

        account.setPasswordHash(passwordEncoder.encode(password));
        account.setStatus(AccountStatus.ACTIVE);
        users.save(account);
    }

    private void createAdmin() {
        UserAccount admin = new UserAccount(
                email,
                passwordEncoder.encode(password),
                firstName,
                lastName,
                Role.ADMIN);
        admin.setStatus(AccountStatus.ACTIVE);
        users.save(admin);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}